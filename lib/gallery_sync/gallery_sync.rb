require 'dropbox_sdk'
require 'aws/s3'
require 'RMagick'
require 'benchmark'
require 'gallery_sync/photo'
require 'gallery_sync/album'

module GallerySync
  class Gallery
    # options, :reload, to reload albums, returns a cached version otherwise.
    def albums(options = {})
      if @albums.nil? or options[:reload]
        @albums = load_albums
      end
      @albums.sort! { |a, b|
        rank_a = a.metadata.fetch('rank', 0)
        rank_b = b.metadata.fetch('rank', 0)
        date_a = a.metadata.fetch('date_from', Date.civil())
        date_b = b.metadata.fetch('date_from', Date.civil())
        if(rank_a == rank_b)
          date_a <=> date_b
        else
          rank_a <=> rank_b
        end
      }.reverse!
      @albums
    end

    def serialized_albums
      ser_albums = []
      albums.each { |album|  
        ser_album = Album.new(album.name)
        ser_album.metadata = album.metadata
        ser_album.album_photo = SerPhoto::value_of(album.album_photo)
        ser_album.photos = []
        album.photos.each { |photo|  
          ser_album.photos << SerPhoto::value_of(photo)
        }
        ser_albums << ser_album
      }
      ser_albums
    end

    def sync_to(dest_gallery)
      src = self

      src_albums = src.albums
      dest_albums = dest_gallery.albums

      to_be_deleted = dest_albums.map(&:name) - src_albums.map(&:name)
      to_be_deleted.each { |album| dest_gallery.rm_album(album) }
      src_albums.each { |album|
        if(dest_gallery[album.name])
          album.merge_to(dest_gallery[album.name], dest_gallery) if dest_gallery[album.name]
        else
          dest_gallery.upload_album(album)
          # sync metadata
          dest_gallery.update_album_metadata(album,album.metadata)
        end
      }
    end

    def [](album_name)
      r = albums.select { |a| a.name == album_name }
      r.empty? ? nil : r.first
    end
  end

  class CacheableGallery < Gallery
    def initialize(gallery)
      @albums = gallery.serialized_albums()    
    end

    def load_albums
      @albums
    end
  end

  class FileGallery < Gallery
    def initialize(name, root_path)
      @root_path = root_path
      @name = name
      @file_lookup = {}
    end

    def load_albums
      albums = []
      album_dirs = Dir.glob(File.join(@root_path,'*',''))
      album_dirs.each { |album_dir|
        album = Album.new(File.basename(album_dir))
        metadata_file = File.join(album_dir, "album.yml")
        album.load_metadata_from_yaml(File.open(metadata_file)) if File.exist?(metadata_file)
        Dir.glob(File.join(album_dir, "*.{png,jpg}")).select { |f| File.file?(f)}.each { |f|
          photo = album.add_photo(File.basename(f))
          @file_lookup[photo] = f
          #Photo.new(album,File.basename(f),f)
        }
        if !album.photos.empty?
          albums << album
          #album.photos = photos
          #album.album_photo = photos[0]
        end
      }
      albums
    end

    def rm_photo photo
      File.delete(@file_lookup[photo])
    end

    def rm_album album_name
      album = self[album_name]
      album.photos.each { |p|
        rm_photo p
      }
    end

    def upload_album album
      Dir.mkdir File.join(@root_path, album.id)
      album.photos.each { |photo|  
        upload_photo(photo) 
      }
    end

    def upload_photo(photo)
      path = File.join(@root_path, photo.album.id, photo.id)
      File.open(path,'wb') {|io|io.write(photo.file)}
    end

    def update_album_metadata(album,metadata)
      file = File.join(@root_path, album.name, "album.yml")
      File.open(file, 'w') do |out| 
        YAML::dump(metadata, out)
      end
    end

    def to_s
      @root_path
    end
  end

  class SerPhoto < Struct.new(:name, :path, :thumb_url, :medium_url, :full_url)
    def self.value_of(photo)
      SerPhoto.new(photo.name,photo.path,photo.thumb_url,photo.medium_url,photo.full_url)
    end
  end

  class FilePhoto < Photo
    def initialize(album,name,filepath)
      super(album,name)
      @filepath = filepath
    end

    def rm
      File.delete @filepath
    end

    def thumb_url
      @filepath
    end

    def medium_url
      @filepath
    end

    def full_url
      @filepath    
    end

    def to_s
      "#{name} (#{@filepath})"
    end

    def file
      File.open(@filepath,"rb") {|io| io.read}
    end
  end

  class DropboxPhoto < Photo
    def initialize(album,name,dropbox_path,gallery)
      super(album,name)
      @dropbox_path = dropbox_path
      @gallery = gallery
    end

    def db_path
      @dropbox_path
    end

    def file
      file =  @gallery.client.get_file(@dropbox_path)
      return file
    end
  end

  class S3Photo < Photo
    def initialize(album,name,s3_path, gallery)
      super(album,name)
      @s3_path = s3_path
      @gallery = gallery
    end

    def s3_path
      @s3_path
    end

    def thumb_url
      key = album.name + "/thumb/" + name
      @gallery.bucket.objects[key].public_url(:secure => false).to_s
    end

    def medium_url
      key = album.name + "/medium/" + name
      @gallery.bucket.objects[key].public_url(:secure => false).to_s
    end

    def full_url
      key = album.name + "/full/" + name
      @gallery.bucket.objects[key].public_url(:secure => false).to_s
    end
  end

  class DropboxSource < Gallery

    # Creates a dropbox source.
    # @param [String] root the dropbox root directory of albums, 
    # given as an absolute directory relative to the dropbox 
    # root directry. Must start with a slash ('/'), e.g. 
    # /Photos/mygallery Directories are handled as albums.
    def initialize(root, app_key, app_secret, user_key, user_secret)
      @root = root
      session = DropboxSession.new(app_key,app_secret)
      session.set_access_token(user_key,user_secret)
      session.assert_authorized
      @client = DropboxClient.new(session,:dropbox)
    end

    def client
      @client
    end

    def getFile photo
      @client.get_file(@root + photo.db_path)
    end

    def load_albums
      albums = []
      # retrieve all albums
      @client.metadata(@root)['contents'].map { |c| c['path'] if c['is_dir'] }.each { |dir|  
        # retrieve all photos
        photos = []
        album = Album.new(File.basename(dir))
        @client.metadata(dir)['contents'].map { |c| c['path'] unless c['is_dir'] }.each { |file|  
          if(file =~ /(\.png|\.jpg)\z/i) 
            photos << DropboxPhoto.new(album, File.basename(file), file, self)
          end 
          if(file =~ /album\.yml\z/)
            album.load_metadata_from_yaml(@client.get_file(file))
          end
        }

        # only add album if it contains at least one photo 
        if( !photos.empty? )
          album.photos = photos
          album.album_photo = photos[0]
          albums << album
        end
      }
      albums
    end
  end

  class S3Destination < Gallery
    def initialize(bucket_name,s3_key,s3_secret)
      @con = AWS::S3::new(
        :access_key_id     => s3_key,
        :secret_access_key => s3_secret
      )
      @bucket = @con.buckets.create bucket_name
    end

    def bucket
      @bucket
    end

    def load_albums 
      albums = []

      dirs = @bucket.as_tree.children.select(&:branch?)
      dirs.each { |dir|  
        photos = []
        album = Album.new(File.basename(dir.prefix))
        metadata = @bucket.objects[File.join(dir.prefix,'album.yml')]
        if(metadata.exists?)
          album.load_metadata_from_yaml(metadata.read)
        end

        dir = dir.children.select(&:branch?)[0]
        if (dir) 
          dir.children.select(&:leaf?).each { |leaf|
            if( !leaf.key.end_with?("/") )  
              photos << S3Photo.new(album, File.basename(leaf.key), leaf.key, self)
            end
          }
        end

        # only add album if it contains at least one photo
        if( !photos.empty? )
          album.photos = photos
          album.album_photo = photos[0]
          albums << album
        end
      }
      albums
    end

    def rm_album album_name
      album = self[album_name]
      album.photos.each { |p|
        rm_photo p
      }
    end

    def rm_photo photo
      key_thumb = photo.album.name + "/thumb/" + photo.name
      key_medium = photo.album.name + "/medium/" + photo.name
      key_full = photo.album.name + "/full/" + photo.name
      @bucket.objects[key_thumb].delete
      @bucket.objects[key_medium].delete
      @bucket.objects[key_full].delete
    end

    def upload_album album
      album.photos.each { |photo|  
        upload_photo(photo) 
      }
    end

    def upload_photo(photo)
      key_thumb = photo.album.name + "/thumb/" + photo.name
      key_medium = photo.album.name + "/medium/" + photo.name
      key_full = photo.album.name + "/full/" + photo.name

      photos = ImageScaler.scale_image(photo.file)

      @bucket.objects.create(key_thumb, :data => photos[:thumb], :acl => :public_read)
      @bucket.objects.create(key_medium, :data => photos[:medium], :acl => :public_read)
      #@bucket.objects.create(key_full, :data => photos[:full], :acl => :public_read)
    end

    def update_album_metadata(album,metadata)
      metadata_key = album.name + "/album.yml"
      @bucket.objects.create(metadata_key, :data => YAML::dump(metadata), :acl => :public_read)
    end

    def to_s 
      @bucket.name
    end
  end


  class ImageScaler 
    # @param image an in-memory image
    # @returns thre different versions of the 
    #          given photo, thumb, medium and full. 
    def self.scale_image(image)
      r = {}

      magick_image = Magick::Image.from_blob(image).first
      magick_image.auto_orient!

      # thumb (strip exif metadata to decrease size)
      # ^ means minimum size
      r[:thumb] = magick_image.change_geometry('100x100^') { |w,h,img|
        resized = img.resize(w,h)
        if(w > h)
          # landscape
          resized.crop((w-h)/2,0,h,h)
        else
          # portrait
          resized.crop(0,0,w,w)
        end
      }.strip!.to_blob {
        self.quality = 80
      }

      # medium
      r[:medium] = magick_image.change_geometry('460x460') { |cols, rows, img|
        img.resize(cols, rows)
      }.to_blob { self.quality = 85 }

      # full
      r[:full] = image
      return r
    end
  end
end

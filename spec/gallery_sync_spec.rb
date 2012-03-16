require 'gallery_sync/gallery_sync'
require 'gallery_sync/album'
require 'tmpdir'

module GallerySync

  describe GallerySync do

    CONFIG_KEYS = [
      'GALLERY_SYNC_S3_KEY',
      'GALLERY_SYNC_S3_SECRET',
      'GALLERY_SYNC_DROPBOX_APP_KEY',
      'GALLERY_SYNC_DROPBOX_APP_KEY',
      'GALLERY_SYNC_DROPBOX_APP_SECRET',
      'GALLERY_SYNC_DROPBOX_USER_KEY',
      'GALLERY_SYNC_DROPBOX_USER_SECRET']

      before (:all) do
        env_file = File.expand_path('../../.env', __FILE__)
        if File.exists? env_file
          env_values = Hash[IO.read(env_file).split.collect {|line| line.split('=')}]
          (CONFIG_KEYS).each { | key |
            ENV[key] = env_values[key]
          }
        end

        missing_config_keys = CONFIG_KEYS - ENV.keys
        raise "missing config key(s): #{missing_config_keys}. Check #{env_file}" unless missing_config_keys.empty?

        @dropbox_empty = DropboxSource.new("/Photos/rubytest/empty", 
                                           ENV['GALLERY_SYNC_DROPBOX_APP_KEY'],
                                           ENV['GALLERY_SYNC_DROPBOX_APP_SECRET'], 
                                           ENV['GALLERY_SYNC_DROPBOX_USER_KEY'],
                                           ENV['GALLERY_SYNC_DROPBOX_USER_SECRET'] )

        @src = DropboxSource.new("/Photos/rubytest/test1", 
                                 ENV['GALLERY_SYNC_DROPBOX_APP_KEY'],
                                 ENV['GALLERY_SYNC_DROPBOX_APP_SECRET'], 
                                 ENV['GALLERY_SYNC_DROPBOX_USER_KEY'],
                                 ENV['GALLERY_SYNC_DROPBOX_USER_SECRET'] )
      end

      describe DropboxSource, "empty dropbox directory" do
        it "should return no albums" do
          @dropbox_empty.albums.should be_empty
        end
      end

      describe DropboxSource, "for each non-empty dropbox directory" do
        before(:all) do
          @albums = @src.albums
        end

        it "an album should be created" do
          @albums.should have(2).items
        end

        it "the albums should have the correct name" do
          @albums[0].name.should == "one"
        end

        it "each file in an album should be depicted as one photo" do
          @albums[0].photos.should have(3).photos 
        end

        it "each photo should contain the correct path" do
          @albums[0].photos[0].db_path.should eq "/Photos/rubytest/test1/one/IMG_0225.jpg"
        end 

        it "each photo should contain the correct path" do
          @albums[0].photos[0].path.should eq "one/IMG_0225.jpg"
        end 

        it "the first photo is the album photo" do
          @albums[0].album_photo.should == @albums[0].photos[0]
        end

        it "should read metadata correctly" do
          @src['one'].metadata['name'].should == "Album 1"
          @src['one'].metadata['date_from'].should == Date.parse('2011-09-09')
          @src['one'].metadata['date_to'].should == Date.parse('2011-09-10')
        end 
      end

      describe Album do
        before(:all) do
          @album = Album.new("album")
          photos = [Photo.new(@album, "p1"), Photo.new(@album,"p2")]
          @album.photos = photos
          @album.album_photo = photos[0]
        end
        it "path of photo must macht <gallery_name>/<photo_name>" do
          @album.photos[0].path.should == "album/p1"
        end
      end

      describe "DropboxToS3" do
        before(:all) do
          @albums = @src.albums
          @dest = S3Destination.new("therech_rubytest_dropbox", ENV['GALLERY_SYNC_S3_KEY'], ENV['GALLERY_SYNC_S3_SECRET'])
        end

        it "should sync the gallery from dropbox to s3" do
          @src.sync_to(@dest) 
          @dest.albums.size.should == @src.albums.size
          @dest['one'].metadata.should == @src['one'].metadata
        end
      end

      describe "FileToS3" do
        before(:all) do
          @gal1_dir  = File.join(File.expand_path(File.dirname(__FILE__)),"resources/gal1")
          @gal1 = FileGallery.new "foo", @gal1_dir 
          @dest = S3Destination.new("therech_rubytest_fromfile",ENV['GALLERY_SYNC_S3_KEY'], ENV['GALLERY_SYNC_S3_SECRET'])
        end

        it "should upload the complete album" do
          @gal1.sync_to(@dest)
          albums = @gal1.albums
          albums.size.should == 2
          album_names = @dest.albums.map(&:name)
          album_names.size.should == 2
          album_names.should include 'album1' 
          album_names.should include 'album2' 
          album_names.should_not include 'album3' 
          album_names.should_not include 'album4' 
          @dest["album2"].photos.size.should == 2
          @dest["album1"].photos.size.should == 3
          @dest["album1"].metadata.should == @gal1['album1'].metadata
        end 
      end

      describe S3Destination, "each directory on s3" do
        before(:all) do
          @dest = S3Destination.new("therech_rubytest",ENV['GALLERY_SYNC_S3_KEY'], ENV['GALLERY_SYNC_S3_SECRET'])
          @albums = @dest.albums
        end

        it "accessor for album" do
          @dest['one'].should_not be nil
          @dest['two'].should_not be nil
          @dest['four'].should be nil
        end

        it "should serialize albums correctly" do
          ser_albums = @dest.serialized_albums()
          albums = Marshal.load(Marshal.dump(ser_albums))
          albums.size.should == 2
        end

        it "should represent an album" do
          @albums.should have(2).items
        end

        it "should return albums in correct order" do
          @albums[0].name.should == "one"
        end

        it "each file in an album should be depicted as one photo" do
          @albums[0].photos.should have(3).photos 
        end

        it "each photo should contain the correct path" do
          @albums[0].photos[0].s3_path.should eq "one/full/IMG_0225.jpg"
        end 

        it "each photo should contain the correct path" do
          @albums[0].photos[0].path.should eq "one/IMG_0225.jpg"
        end 

        it "the first photo is the album photo" do
          @albums[0].album_photo.should == @albums[0].photos[0]
        end

        it "should have three versions of photos" do
          @albums[0].photos[0].full_url.should match "one/full/IMG_0225.jpg"
          @albums[0].photos[0].medium_url.should match "one/medium/IMG_0225.jpg"
          @albums[0].photos[0].thumb_url.should match "one/thumb/IMG_0225.jpg"
        end

        it "should read metadata correctly" do
          @dest['one'].metadata['name'].should == "Album 1"
          @dest['one'].metadata['date_from'].should == Date.parse('2011-09-09')
          @dest['one'].metadata['date_to'].should == Date.parse('2011-09-10')
        end 
      end

      # test gallery looks as follows:
      #  -gal1
      #    -album1
      #      -p1.png
      #      -p2.png
      #      -p3.png
      #    -album2
      #      -empty_dir
      #      -p1.png
      #      -p4.png
      #    -album3
      describe FileGallery do  
        before(:all) do
          @gal1_dir  = File.join(File.expand_path(File.dirname(__FILE__)),"resources/gal1")
          @gal1 = FileGallery.new "foo", @gal1_dir 
        end

        it "should serialize albums correctly" do
          ser_albums = @gal1.serialized_albums()
          albums = Marshal.load(Marshal.dump(ser_albums))
          albums.size.should == 2
        end

        it "empty albums must not be included" do
          @gal1.albums.size.should == 2
        end

        it "albums should have the name of the directory" do
          album_names = @gal1.albums.map(&:name)
          album_names.should include 'album1' 
          album_names.should include 'album2' 
          album_names.should_not include 'album3' 
        end

        it "directories in albums must be ignored" do
          @gal1["album2"].photos.size.should == 2
          @gal1["album1"].photos.size.should == 3
        end

        it "shuld read metadata correctly" do
          @album1 = @gal1['album1']
          metadata = @album1.metadata() 
          @album1.name.should == "album1"
          metadata['name'].should == "Album 1"
          metadata['date_from'].should == Date.parse('2011-09-09')
          metadata['date_to'].should == Date.parse('2011-09-10')
        end

        # provides src and dest gallery through a block
        def sync()
          #dir = Dir.mktmpdir

          Dir.mktmpdir{ |dir| 
            FileUtils.cp_r @gal1_dir, dir
            dest = File.join(dir, "gal1")
            File.delete File.join(dest, 'album1/p1.png')
            File.delete File.join(dest, 'album1/album.yml')
            FileUtils.cp File.join(@gal1_dir, 'album1/p1.png'), File.join(dest, 'album3')
            FileUtils.cp File.join(@gal1_dir, 'album1/p2.png'), File.join(dest, 'album2')
            Dir.mkdir File.join(dest, 'album4')
            FileUtils.cp_r Dir.glob(File.join(@gal1_dir, 'album1', '/*')), File.join(dest, 'album4')

            @gal2 = FileGallery.new "gal2", dest
            @gal1.sync_to(@gal2)
            @gal2 = FileGallery.new "gal2", dest
            yield(@gal1,@gal2)
          }
        end

        # destination album is created on the fly in temp directory
        # content is as follows
        # -gal1
        #   -album1
        #     -p2.png
        #     -p3.png
        #   -album2
        #     -empty_dir
        #     -p1.png
        #     -p2.png
        #     -p4.png
        #   -album3
        #     -p1.png
        #   -album4
        #     -p1.png
        #     -p2.png
        #     -p3.png
        it "sync_to" do
          sync() { |src,dst|
            album_names = dst.albums.map(&:name)
            album_names.size.should == 2
            album_names.should include 'album1' 
            album_names.should include 'album2' 
            album_names.should_not include 'album3' 
            album_names.should_not include 'album4' 
            dst["album2"].photos.size.should == 2
            dst["album1"].photos.size.should == 3
          }
        end

        it "should sync metadata" do
          sync() { |src,dst|
            src_album = src['album1']
            dst_album = dst['album1']
            dst_album.metadata.should == src_album.metadata
          }
        end

        it "should sync full album when dest is empty" do
          Dir.mktmpdir {|dir|
            gal_dir = File.join(dir, "gal")
            Dir.mkdir gal_dir
            gal = FileGallery.new "gal", gal_dir

            @gal1.sync_to(gal)
            gal = FileGallery.new "gal", gal_dir
            album_names = gal.albums.map(&:name)
            album_names.size.should == 2
            album_names.should include 'album1' 
            album_names.should include 'album2' 
            album_names.should_not include 'album3' 
            album_names.should_not include 'album4' 
            gal["album2"].photos.size.should == 2
            gal["album1"].photos.size.should == 3
          }
        end
      end

      describe Album, "get_merge_actions" do
        before(:all) do
          @src = Album.new "album"
          @dest = Album.new "album" 

          @src.photos = [
            Photo.new(@src,"f1"),
            Photo.new(@src, "f2"),
            Photo.new(@src, "f3")]

            @dest.photos = [
              Photo.new(@dest,"f2"),
              Photo.new(@dest, "f5")]
              @diff = @src.get_merge_actions(@dest)
        end

        it "returns the difference between two path" do
          @diff[:add].should == [Photo.new(@src,"f1"),Photo.new(@src,"f3")]
          @diff[:delete].should == [Photo.new(@dest,"f5")]
        end
      end

      describe Photo do
        before(:all) do
          @a1 = Album.new("a1")
          @a2 = Album.new("a2")
        end

        it { Photo.new(@a1,"p1").should == Photo.new(@a2, "p1") }
        it { Photo.new(@a1,"p1").should == Photo.new(@a1, "p1") }
        it { Photo.new(@a1,"p1").should_not == Photo.new(@a1, "p2") }
      end

      describe ImageScaler do
        describe "scale_image" do
          it "should return 3 differently scaled versions" do
            portrait = File.join(File.expand_path(File.dirname(__FILE__)),
                                 "resources/images/portrait.jpg")
            landscape = File.join(File.expand_path(File.dirname(__FILE__)),
                                  "resources/images/landscape.jpg")

            file_portrait = open(portrait, "rb") {|io| io.read }
            file_landscape = open(landscape, "rb") {|io| io.read }
            scaled_images_portrait = ImageScaler.scale_image(file_portrait)
            scaled_images_landscape = ImageScaler.scale_image(file_landscape)
            #p scaled_images[:thumb].size
            #p scaled_images[:medium].size
            #p scaled_images[:full].size

            med_file = open("/tmp/portrait_thumb.jpg", "wb").write(scaled_images_portrait[:thumb])
            med_file = open("/tmp/portrait_med.jpg", "wb").write(scaled_images_portrait[:medium])
            med_file = open("/tmp/portrait_full.jpg", "wb").write(scaled_images_portrait[:full])

            med_file = open("/tmp/landscape_thumb.jpg", "wb").write(scaled_images_landscape[:thumb])
            med_file = open("/tmp/landscape_med.jpg", "wb").write(scaled_images_landscape[:medium])
            med_file = open("/tmp/landscape_full.jpg", "wb").write(scaled_images_landscape[:full])
          end
        end
      end
  end
end

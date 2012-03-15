require 'gallery_sync/photo'
require 'gallery_sync/album_patch'
module GallerySync
  class Album
    attr_reader :id, :photos
    attr_accessor :metadata

    def initialize(id,options = {})
      @id = id
      @photos = {}
      @metadata = options.select { |k,v| 
        [:name,:description,:date_from,:date_to,:rank,:album_photo].include?(k) 
      }
    end

    def add_photo(id, options = {})
      if(id.is_a? Photo)
        add_photo(id.id,id.metadata.merge(options)) 
      else
        @photos[id] = Photo.new(id,self,options)
      end
    end

    alias :name :id

    def remove_photo(id)
      @photos.delete(id)
    end

    def [](photo_id)
      photos[photo_id]
    end

    def album_photo
      @photos[0]
    end

    # Compares this album with another_album and returns
    # a patch object that can be applied to this album to 
    # reproduce the state of the other_album.
    #
    # See GallerySync::AlbumPatch 
    def diff (other_album)
      a = self
      b = other_album
      a_ids = a.photos.keys
      b_ids = b.photos.keys

      # in b but not in a (added)
      added_ids = b_ids - a_ids
      added = b.photos.values_at(*added_ids)

      # in a but not in b (removed)
      removed_ids = a_ids - b_ids;
      removed = a.photos.values_at(*removed_ids)

      # in a and b but with different metadata
      common_ids = a_ids & b_ids

      changed_ids = common_ids.select do |id|
        photo_a = @photos[id]
        photo_b = other_album.photos[id]
        not photo_a.metadata_equal?(photo_b)
      end

      changed = b.photos.values_at(*changed_ids)
      AlbumPatch.new(added, removed, changed) 
    end

    def apply_patch(patch)
      a = self.clone
      patch.added.each do |p|
        a.add_photo(p)  
      end

      patch.removed.each do |p|
        a.remove_photo p.id
      end

      patch.changed.each do |p|
        a.add_photo(p)
      end
      return a
    end

    def clone
      a = Album.new @id
      @photos.values.each { |v|
        a.add_photo(v)  
      }
      return a
    end

    # loads metadata from a yaml string
    # title, date_from, date_to
    def load_metadata_from_yaml(file)
      @metadata = {}
      @metadata = YAML::load(file)
    end


    def get_merge_actions(dest_album)
      r = {}
      src_album = self
      src_names = @photos.collect(&:name)
      dest_names = dest_album.photos.collect(&:name)

      to_add = src_names - dest_names
      to_delete = dest_names - src_names

      r[:add] = to_add.map { |name| src_album[name]  }
      r[:delete] = to_delete.map { |name| dest_album[name]  }
      return r
    end

    def merge_to(dest_album,dest_gallery)
      merge_actions = get_merge_actions(dest_album)

      # perform delete
      merge_actions[:delete].each { |p|
        dest_gallery.rm_photo p
      }

      # perform add
      merge_actions[:add].each { |p|
        dest_gallery.upload_photo(p)
      }

      # sync metadata
      if(self.metadata != dest_album.metadata)
        dest_gallery.update_album_metadata(dest_album,self.metadata)
      end 
    end

    def ==(other)
      if other.is_a? Album
        @id == other.id
      else
        false
      end
    end

    def to_s
      @id
    end
  end
end

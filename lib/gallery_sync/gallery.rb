module GallerySync
  class Gallery
    attr_reader :albums, :id

    def initialize(id)
      @id = id
      @albums = {}
    end

    def add_album(album)
      @albums[album.id] = album
    end

    def [](album_id)
      albums[album_id]
    end


    # Compares this gallery with another gallery and returns
    # a patch object that can be applied to this gallery to 
    # reproduce the state of the other gallery
    #
    # See GallerySync::GalleryPatch 
    def diff (other_gallery)
      a = self
      b = other_gallery

      a_ids = a.albums.keys
      b_ids = b.albums.keys

      # in b but not in a (added)
      added_ids = b_ids - a_ids
      added = b.albums.values_at(*added_ids)

      # in a but not in b (removed)
      removed_ids = a_ids - b_ids;
      removed = a.albums.values_at(*removed_ids)

      # in a and b but with differences in album/photos
      common_ids = a_ids & b_ids

      changed = {}
      changed_ids = common_ids.select do |id|
        album_a = @albums[id]
        album_b = other_gallery.albums[id]
        patch = album_a.diff(album_b)
        changed[id] = patch unless patch.empty?
        #TODO: AlbumPatch should contain diff to new metadata (rank, description, dates)
      end

      AlbumPatch.new(added, removed, changed) 
    end
  end
end

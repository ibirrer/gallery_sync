module GallerySync
  class MockGalleryDriver
    def initialize(gallery)
      @gallery = gallery
    end

    def gallery
      @gallery
    end
    
    def remove_album a
      @gallery.remove_album(a.id)
    end

    def add_album a
      @gallery.add_album a.id, a.metadata
      a.photos.each do |p|
        add_photo p
      end
    end

    def delete_photo p
      @gallery[p.album.id].remove_photo(p.id)
    end

    def add_photo p
      @gallery[p.album.id].add_photo(p.id,p.metadata)
    end

    def update_photo p
      @gallery[p.album.id].add_photo(p.id,p.metadata)
    end
  end
end

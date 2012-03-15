module GallerySync
  # Represenst a photo in an album of the gallery. A photo
  # can only exists in an album. The id of a photo is given
  # by its id and the the album it is contained in.
  class Photo
    attr_reader :id, :album
    
    def initialize(id, album, options = {})
      fail unless album.is_a? Album
      @id = id
      @album = album
      @metadata = options.select { |k,v| 
        [:name,:description,:date_taken].include?(k) 
      }
      @metadata.freeze
    end

    def name
      @metadata[:name]
    end

    def description
      @metadata[:description]
    end

    def date_taken
      @metadata[:date_taken]
    end

    def metadata_equal?(other)
      return @metadata == other.metadata
    end

    def hash 
      (@id + @album.id).hash 
    end 

    def metadata
      @metadata
    end

    def ==(other)
      if other.is_a? Photo
        @id == other.id && @album == other.album
      else
        false
      end
    end

    def eql?(other) 
      self==other
    end
  end
end

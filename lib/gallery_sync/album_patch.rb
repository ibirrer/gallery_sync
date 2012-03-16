module GallerySync
  # Patch that desribes the difference between two albums.    
  class AlbumPatch

    def initialize(added, removed, changed)
      @added = added
      @removed = removed
      @changed = changed
    end

    # Photos which are present in album _a_ but not in _b_
    def removed
      @removed
    end

    # Photos which are present in album _a_ and _b_ but for which the metadata is different
    def changed
      @changed
    end

    # Photos which are present in album _b_ but not in _a_
    def added
      @added
    end

    # returns +true+ if this patch does not contain any differences
    def empty?
      @added.empty? and @removed.empty? and @changed.empty?
    end
  end
end

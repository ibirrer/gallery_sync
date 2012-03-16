module GallerySync
  # Patch that desribes the difference between two galleries.    
  class GalleryPatch

    def initialize(added, removed, changed)
      @added = added
      @removed = removed
      @changed = changed
    end

    # Albums which are present in gallery _a_ but not in _b_
    def removed
      @removed
    end

    # A set of GallerySync::AlbumPatch instances that describe 
    # the changes for albums which are are present in gallery
    # _a_ and _b_ but are not equal.
    def changed
      @changed
    end

    # Albums which are present in gallery _b_ but not in _a_
    def added
      @added
    end
  end
end

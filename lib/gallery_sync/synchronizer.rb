module GallerySync
  class Synchronizer
    def initialize(source,target)
      fail unless source.is_a? Endpoint
      fail unless target.is_a? Endpoint

      @source = source
      @target = target
    end

    def sync
      patch = @target.gallery.diff(@source.gallery)
      @target.patch patch
    end
  end
end

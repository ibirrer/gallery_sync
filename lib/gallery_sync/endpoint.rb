module GallerySync
  class Endpoint
    def initialize driver
      @driver = driver
    end

    def gallery
      @driver.gallery
    end

    def patch(patch)
      patch.removed.each do |a|
        @driver.remove_album a
      end

      patch.added.each do |a|
        @driver.add_album a
      end

      patch.changed.each do |p|
        patch_album p
      end
    end

    def patch_album patch
      patch.removed.each do |p| 
        @driver.delete_photo p
      end

      patch.added.each do |p|
        @driver.add_photo p
      end

      patch.changed.each do |p|
        @driver.update_photo p
      end
    end
  end
end

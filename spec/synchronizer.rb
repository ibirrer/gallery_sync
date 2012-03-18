require "gallery_sync/synchronizer"
require "gallery_sync/endpoint"
require "gallery_sync/gallery"
require "gallery_sync/album"
require "gallery_sync/photo"
require "mock_gallery_driver.rb"


module GallerySync
  describe Synchronizer do
    describe "sync" do

      before(:each) do
        @g1 = Gallery.new "g1"
        @g1.add_album "a1"
        @g1.add_album "a2"
        @g1["a2"].add_photo "p1"
        @g1["a2"].add_photo "p2"
        @g1["a2"].add_photo "p3"
        @g1.add_album "a3"
       
        # a1: no change 
        # a2: changed
        #   ↳ p1: no change 
        #   ↳ p2: changed
        #   ↳ p3: removed
        #   ↳ p4: added
        # a3: removed
        # a4: added
        @g2 = Gallery.new "g2"
        @g2.add_album "a1"
        @g2.add_album "a2"
        @g2["a2"].add_photo "p1"
        @g2["a2"].add_photo "p2", :name => "photo 2"
        @g2["a2"].add_photo "p4"
        @g2.add_album "a4"
      end
      

      it "synchronizes the state of the source endpoint to a target endpoint" do
        sourceDriver = MockGalleryDriver.new @g1
        targetDriver = MockGalleryDriver.new @g2

        source = Endpoint.new(sourceDriver)
        target = Endpoint.new(targetDriver)

        syncr = Synchronizer.new(source,target)
        syncr.sync

        g = target.gallery
        g.albums.size.should == 3
        g.albums["a1"].should_not be_nil
        g.albums["a2"].should_not be_nil
        g.albums["a3"].should_not be_nil
        #TODO: more tests
      end
    end
  end
end

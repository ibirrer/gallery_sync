require 'gallery_sync/gallery'
require 'gallery_sync/album'

module GallerySync
  describe Gallery do 
    describe "add_album" do
      before(:each) do
        @g = Gallery.new "g1"
        @g.add_album "a1"
        @g.add_album "a2"
      end
      it "should keep albums with the same id" do
        @g.albums.size.should == 2
      end

      it "should replace already existing albums with the same id" do
        @g.add_album "a2", :name => "album 2"
        @g.albums.size.should == 2
        @g["a2"].name.should == "album 2"
      end
    end

    describe "diff" do
      before(:each) do
        @g1 = Gallery.new "g1"
        @g1.add_album "a1"
        @g1.add_album "a2"
        
        @g2 = Gallery.new "g2"
        @g2.add_album "a1"
        @g2.add_album "a2"
      end

      it "should return an empty patch if two galleries have the same content" do
        patch = @g1.diff(@g2)

        patch.added.should be_empty
        patch.removed.should be_empty
        patch.changed.should be_empty
        patch.empty?.should == true
      end 

      it "should identify added albums" do
        @g2.add_album "a3"
        patch = @g1.diff(@g2)
        patch.added.size.should == 1
        patch.removed.should be_empty
        patch.changed.should be_empty
        patch.empty?.should == false
      end
      
      it "should identify removed albums" do
        @g1.add_album "a3"
        patch = @g1.diff(@g2)
        patch.removed.size.should == 1
        patch.added.should be_empty
        patch.changed.should be_empty
        patch.empty?.should == false
      end

      it "should identify albums with different content" do
        a1 = Album.new "a1"
        @g1.add_album("a1")
        @g1["a1"].add_photo "p1"
        patch = @g1.diff(@g2)
        patch.changed.size.should == 1
        patch.added.should be_empty
        patch.removed.should be_empty
        patch.empty?.should == false
      end
    end
  end
end

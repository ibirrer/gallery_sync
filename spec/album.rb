require 'gallery_sync/album'
require 'date'

module GallerySync
  describe Album do
    it "two albums with the same id should be considered equal" do
      a = Album.new "a"
      b = Album.new "a"
      (a == b).should == true
    end
    
    it "two albums with differen ids should not be considered equal" do
      a = Album.new "a"
      b = Album.new "b"
      (a == b).should == false
    end

    describe "add_photo()" do
      it "adds photos to the album" do
        a = Album.new "a"
        a.add_photo("1")

        a.photos.size.should == 1
        a["1"].should_not be_nil
      end

      it "should replace photo if it already exists" do
        a = Album.new "a"
        a.add_photo("1")
        a.add_photo("1", :name => "foo")

        a.photos.size.should == 1
        a["1"].name.should == "foo"
      end

      it "should return the newly added photo" do
        a = Album.new "a"
        a.add_photo("1").id.should == "1"
      end      

      it "should add an already existing photo by cloning it" do
        a = Album.new "a"
        b = Album.new "b"
        a.add_photo("1", :name => "foo", :description => "foo")
        b.add_photo(a["1"], :name => "bar")

        b["1"].name.should == "bar"
        b["1"].description.should == "foo"
        b["1"].album.should == b
      end
    end

    it "clone" do
      a = Album.new "a"
      a.add_photo("p1")
      a.add_photo("p2", :name => "photo1")
      
      b = a.clone

      b.photos.size.should == a.photos.size
      b["p1"].album.should == b
      b["p2"].name.should == "photo1"
    end

    describe "[]" do
      it "returns a photo by its id" do
        a = Album.new "a"
        a.add_photo "1"
        a.add_photo "2"

        a["1"].id.should == "1"
        a["2"].id.should == "2"
      end

      it "returns nil if a photo with the given id is not contained in the album" do
        a = Album.new "a"
        a.add_photo "1"
        a.add_photo "2"

        a["3"].should be_nil
      end
    end


    describe "diff and patch" do
      before(:each) do
        @a = Album.new "a"
        @a.add_photo("1")
        @a.add_photo("2")
        @a.add_photo("3")
        @a.add_photo("4")

        @b = Album.new "b"
        @b.add_photo("1")
        @b.add_photo("2")
        @b.add_photo("3")
        @b.add_photo("4")
      end

      it "diff with itself or with an equal album should be empty" do
        patch = @a.diff(@a)

        patch.added.should be_empty
        patch.removed.should be_empty
        patch.changed.should be_empty

        patch1 = @a.diff(@b)
        patch1.added.should be_empty
        patch1.removed.should be_empty
        patch1.changed.should be_empty
      end

      it "patch should contain photos that were added" do
        @b.add_photo("5")

        patch = @a.diff(@b)
        patch.added[0].should == @b["5"]
        patch.removed.should be_empty
      end

      it "patch should contain photos that were removed" do
        @a.add_photo("5")

        patch = @a.diff(@b)
        patch.added.should be_empty
        patch.removed[0].should == @a["5"]
      end

      it "patch should contain photos which have different metadata" do
        @a.add_photo("5", :name => "photoa")
        @b.add_photo("5", :name => "photoa_1")

        patch = @a.diff(@b)
        patch.changed.size.should == 1
        patch.changed[0].should == @b["5"]
        patch.changed[0].name == "photoa_1"

        patch.added.should be_empty
        patch.removed.should be_empty
      end

      it "applying the patch should re-create the album from which the patch was created" do
        @a.add_photo("5")
        @b.add_photo("6")
        @a.add_photo("7", :name => "photoa")
        @b.add_photo("7", :name => "photoa_1", :description => "dd", :date_taken => Date.parse('2012-02-10'))
        @b.add_photo("8")

        # @a: 1,2,3,4,5,7*
        # @b: 1,2,3,4,6,7*,8

        patch = @a.diff(@b)

        @c = @a.apply_patch(patch) 

        @c.photos.size.should == @b.photos.size
        @c["7"].name.should == "photoa_1"
        @c["7"].description.should == "dd"
        @c["7"].date_taken.should == Date.parse('2012-02-10') 
        @c["5"].should be_nil
        @c["8"].should_not be_nil
      end
    end
  end
end

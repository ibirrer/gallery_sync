require 'gallery_sync/photo'
require 'gallery_sync/album'
require 'date'

module GallerySync
  describe Photo do
    it "two photos with the same id should be considered equal" do
      a = Album.new "a"
      p1 = Photo.new("1",a)
      p2 = Photo.new("1",a)

      (p1 == p2).should == true
      (p1.eql? p2).should == true
    end
    
    it "two photos with different ids should not be considered equal" do
      a = Album.new "a"
      p1 = Photo.new("1",a)
      p2 = Photo.new("2",a)

      (p1 == p2).should == false
      (p1.eql? p2).should == false
    end

    it "two photos with a different album but the same id must not be equal" do
      a = Album.new "a"
      b = Album.new "b"
      p1 = Photo.new("1",a)
      p2 = Photo.new("1",b)

      (p1 == p2).should == false
      (p1.eql? p2).should == false
    end

    it "options" do
      a = Album.new "a"
      p1 = Photo.new("p1",a,
                     :name => "photo1",
                     :description => "description",
                     :date_taken => Date.parse('2012-02-02'))

      p1.name.should == "photo1"
      p1.description.should == "description"
      p1.date_taken.should == Date.parse('2012-02-02')
    end

    describe "metadata" do
      it "comparing metadata shall include name, description and date_taken" do
        a = Album.new "a"

        m0 = {:name => "photo-1", 
          :description => "descr 1", 
          :date_taken => Date.parse('2012-02-02')}

        m1 = m0.clone
        m2 = m0.clone
        m3 = m0.clone

        m1[:name] = "photo-2"
        m2[:description] = "descr 2"
        m3[:date_taken] = Date.parse('2012-02-01')

        p1 = Photo.new("p1",a,m0)
        p2 = Photo.new("p1",a,m0) 
        p1.metadata_equal?(p2).should == true

        p1 = Photo.new("p1",a,m0)
        p2 = Photo.new("p1",a,m1) 
        p1.metadata_equal?(p2).should == false

        p1 = Photo.new("p1",a,m0)
        p2 = Photo.new("p1",a,m2) 
        p1.metadata_equal?(p2).should == false


        p1 = Photo.new("p1",a,m0)
        p2 = Photo.new("p1",a,m3) 
        p1.metadata_equal?(p2).should == false
      end
    end

  end
end

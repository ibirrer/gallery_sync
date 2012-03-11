# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "gallery_sync/version"

Gem::Specification.new do |s|
  s.name        = "gallery_sync"
  s.version     = GallerySync::VERSION
  s.authors     = ["Iwan Birrer"]
  s.email       = ["iwanbirrer@bluewin.ch"]
  s.homepage    = "https://github.com/ibirrer/gallery_sync"
  s.summary     = %q{Photo gallery syncing for Amazon S3, Dropbox}
  s.description = %q{Synchronizes directory based photo galleries between Amazon S3, Dropbox, local file system. Built for the purpose of managing a photo gallery solely through Dropbox and publishing it trhough Amazon S3. No Database involved, all metdata (e.g album descriptions is kept in the filesystem.}



  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # runtime dependencies
  s.add_runtime_dependency "dropbox-sdk"
  s.add_runtime_dependency "rmagick", ">= 2.12.0"
  s.add_runtime_dependency "aws-sdk"

  # development dependencies
  s.add_development_dependency "rspec"
end

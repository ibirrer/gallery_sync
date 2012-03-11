require 'dropbox_sdk'
module GallerySync 
  class Tasks
    extend Rake::DSL if defined? Rake::DSL
    def self.install
      namespace :gallery do
        desc "Authorize Dropbpox"
        task :authorize_dropbox do
          # prompt app key and secret
          print "Enter dropbox app key: "
          app_key = $stdin.gets.chomp
          print "Enter dropbox app secret: "
          app_secret = $stdin.gets.chomp

          # authorize user
          session = DropboxSession.new(app_key,app_secret)
          session.get_request_token
          authorize_url = session.get_authorize_url
          puts "AUTHORIZING"
          puts authorize_url
          print "Please visit that website and hit 'Allow', then hit Enter here."
          $stdin.gets.chomp
          
          # print configuration
          access_token = session.get_access_token
          puts "\nAdd the following configuration to your .env file:\n\n"
          puts "GALLERY_SYNC_DROPBOX_APP_KEY=#{app_key}"
          puts "GALLERY_SYNC_DROPBOX_APP_SECRET=#{app_secret}"
          puts "GALLERY_SYNC_DROPBOX_USER_KEY=#{access_token.key}"
          puts "GALLERY_SYNC_DROPBOX_USER_SECRET=#{access_token.secret}"
          puts "\n"
        end
      end
    end
  end
end

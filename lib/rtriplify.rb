require 'configatron'

#loading helpers and controllers

%w{ models controllers helpers}.each do |dir|
  path = File.join(File.dirname(__FILE__), 'app', dir)
  $LOAD_PATH << path
  ActiveSupport::Dependencies.load_paths << path
  ActiveSupport::Dependencies.load_once_paths.delete(path)
end

# load settings
configatron.configure_from_yaml('vendor/plugins/rtriplify/lib/config/database.yml')





require 'configatron'

if File.exists?('config/triplify.yml')
  #loading all plugin files
  %w{ models controllers helpers}.each do |dir|
    path = File.join(File.dirname(__FILE__), 'app', dir)
    $LOAD_PATH << path
    ActiveSupport::Dependencies.load_paths << path
    ActiveSupport::Dependencies.load_once_paths.delete(path)
  end
  # load settings from conig
  configatron.configure_from_yaml('config/triplify.yml')
  #register Mime-type
  Mime::Type.register "text/n3", :n3
end





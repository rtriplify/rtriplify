# Include hook code here

require_dependency  'rtriplify'

require 'configatron'

Hash.class_eval do
  def is_a_special_hash?
    true
  end
end
#set the routes for triplify
ActionController::Routing::Routes.draw do |map|

#  map.connect 'triplify/:action', :controller => 'triplify', :action => 'model'
  map.connect 'triplify', :controller => 'triplify', :action => 'all'
  map.connect 'triplify/:model/:id', :controller => 'triplify', :action => 'model', :id => /\d*/
  map.connect 'triplify/*specs', :controller => 'triplify', :action => "index"
  #map.connect '/rtriplify/*', :controller => 'rtriplify', :action => 'index'
end

#["rtriplify"].each do |plugin_name|
#  reloadable_path = RAILS_ROOT + "/vendor/plugins/rtriplify/lib"

#ActiveSupport::Dependencies.load_once_paths.delete(reloadable_path)


#configatron.configure_from_yaml('config/database_1.yml')
#configatron.configure_from_yaml('vendor/plugins/rtriplify/lib/config/database.yml')


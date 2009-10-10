ActionController::Routing::Routes.draw do |map|
  map.connect 'projects/:project_id/schedules', :controller => 'schedules', :action => 'index' 
  map.connect 'projects/:project_id/schedules/edit', :controller => 'schedules', :action => 'edit' 
  map.connect 'projects/:project_id/schedules/report', :controller => 'schedules', :action => 'report' 
  map.connect 'projects/:project_id/schedules/details', :controller => 'schedules', :action => 'details'
  map.connect 'projects/:project_id/schedules/fill', :controller => 'schedules', :action => 'fill' 
  map.connect 'account/schedule/:user_id', :controller => 'schedules', :action => 'index'
  map.connect 'account/schedule/:user_id/edit', :controller => 'schedules', :action => 'edit'
  map.connect 'account/schedule/:user_id/default', :controller => 'schedules', :action => 'default'
  map.connect 'my/schedule', :controller => 'schedules', :action => 'my_index'
end

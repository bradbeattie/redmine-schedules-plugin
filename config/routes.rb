RedmineApp::Application.routes.draw do
  match 'schedules', :controller => 'schedules', :action => 'index'
  match 'schedules/users', :controller => 'schedules', :action => 'users'
  match 'schedules/projects', :controller => 'schedules', :action => 'projects'
  match 'my/schedule', :controller => 'schedules', :action => 'my_index'
  match 'account/schedule/:user_id', :controller => 'schedules', :action => 'index'
  match 'account/schedule/:user_id/default', :controller => 'schedules', :action => 'default'
  match 'account/schedule/:user_id/edit', :controller => 'schedules', :action => 'edit'
  match 'projects/:project_id/schedules', :controller => 'schedules', :action => 'index'
  match 'projects/:project_id/schedules/details', :controller => 'schedules', :action => 'details'
  match 'projects/:project_id/schedules/edit', :controller => 'schedules', :action => 'edit'
  match 'projects/:project_id/schedules/fill', :controller => 'schedules', :action => 'fill'
end

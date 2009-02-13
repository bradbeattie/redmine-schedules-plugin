require 'redmine'

Redmine::Plugin.register :redmine_schedules do
	name 'Redmine Schedules plugin'
	author 'Brad Beattie'
	description 'This plugin provides instances of Redmine a method with which to allocate users to projects and to track this allocation over time. It does so by creating daily time estimates of hours worked per project per user.'
	version '0.1.0'
  
	project_module :schedule_module do
		permission :view_schedules,  {:schedules => [:index]}, :require => :member
		permission :edit_own_schedules, {:schedules => [:edit, :user, :project]}, :require => :member
		permission :edit_all_schedules, {}, :require => :member
	end
	
	menu :top_menu, :schedules, { :controller => 'schedules', :action => 'index', :project_id => nil, :user_id => nil }, :caption => :label_schedules_index, :if => Proc.new { Project.find(:all, :conditions => Project.allowed_to_condition(User.current, :view_schedules)).size > 0 }
	menu :project_menu, :schedules, { :controller => 'schedules', :action => 'index' }, :caption => :label_schedules_index, :after => :activity, :param => :project_id
end

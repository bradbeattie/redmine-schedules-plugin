require 'redmine'

require 'redmine_compatibility'

Redmine::Plugin.register :redmine_schedules do
	name 'Redmine Schedules plugin'
	author 'Brad Beattie'
	description 'This plugin provides instances of Redmine a method with which to allocate users to projects and to track this allocation over time. It does so by creating daily time estimates of hours worked per project per user.'
	version '0.4.0'
  
	project_module :schedule_module do
		permission :view_schedules,  {:schedules => [:index]}, :require => :member
		permission :edit_own_schedules, {:schedules => [:edit, :user, :project]}, :require => :member
		permission :edit_all_schedules, {}, :require => :member
	end
	
	menu :top_menu, :schedules, { :controller => 'schedules', :action => 'my_index', :project_id => nil, :user_id => nil }, :after => :my_page, :caption => :label_schedules_my_index, :if => Proc.new { SchedulesController.visible_projects.size > 0 }
	menu :project_menu, :schedules, { :controller => 'schedules', :action => 'index' }, :caption => :label_schedules_index, :after => :activity, :param => :project_id
end

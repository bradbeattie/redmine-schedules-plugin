require 'redmine'
require 'holidays'
require 'holidays/ca'       # Edit this to the most appropriate holiday region for you: http://code.dunae.ca/svn/holidays/trunk/data/
$holiday_locale = 'ca_bc'   # Set this to the same region (or subregion if appropriate)

require_dependency 'schedule_compatibility'

Redmine::Plugin.register :redmine_schedules do
    name 'Redmine Schedules plugin'
    author 'Brad Beattie'
    description 'This plugin provides instances of Redmine a method with which to allocate users to projects and to track this allocation over time. It does so by creating daily time estimates of hours worked per project per user.'
    url 'https://github.com/bradbeattie/redmine-schedules-plugin'
    version '0.5.0'
    requires_redmine :version_or_higher => '2.1.0'

    project_module :schedule_module do
        permission :view_schedules,  {:schedules => [:index]}, :require => :member
        permission :edit_own_schedules, {:schedules => [:edit, :user, :project]}, :require => :member
        permission :edit_all_schedules, {}, :require => :member
    end

    menu :top_menu, :schedules, { :controller => 'schedules', :action => 'my_index', :project_id => nil, :user_id => nil }, :after => :my_page, :caption => :label_schedules_my_index, :if => Proc.new { SchedulesController.visible_projects.size > 0 }
    menu :project_menu, :schedules, { :controller => 'schedules', :action => 'index' }, :caption => :label_schedules_index, :after => :activity, :param => :project_id
end

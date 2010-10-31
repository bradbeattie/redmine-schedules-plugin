class SchedulesController < ApplicationController
    unloadable


    ############################################################################
    # Initialization
    ############################################################################


    # Filters
    before_filter :require_login
    before_filter :load_params
    before_filter :find_users_and_projects, :only => [:index, :edit, :users, :projects, :fill]
    before_filter :find_optional_project, :only => [:report, :details]
    before_filter :save_entries, :only => [:edit]
    before_filter :save_default, :only => [:default]
    before_filter :fill_entries, :only => [:fill]
    
    # Included helpers
    include SchedulesHelper
    include SortHelper
    helper :sort
    

    ############################################################################
    # Class methods
    ############################################################################
    
    
    # Return a list of the projects the user has permission to view schedules in
    def self.visible_projects
        Project.find(:all, :conditions => Project.allowed_to_condition(User.current, :view_schedules))
    end
    
    
    # Return a list of the users in the given projects which have permission to view schedules
    def self.visible_users(members)
      members.select {|m| m.roles.detect {|role| role.allowed_to?(:view_schedules)}}.collect {|m| m.user}.uniq.sort
    rescue    
      members.select {|m| m.role.allowed_to?(:view_schedules)}.collect {|m| m.user}.uniq.sort
    end


    ############################################################################
    # Public actions
    ############################################################################
    
    
    # View the schedule for the given week/user/project
    def index
        unless @users.empty?
            @entries = get_entries
            @availabilities = get_availabilities
            render :action => 'index', :layout => !request.xhr?
        end
    end
    
    #
    def projects
        @focus = "projects"
        index
    end

    #
    def users
        @focus = "users"
        index
    end
    
    
    # View the schedule for the given week for the current user
    def my_index
        params[:user_id] = User.current.id
        find_users_and_projects
        index
    end
    
    
    # Edit the current user's default availability
    def default
        @schedule_default = ScheduleDefault.find_by_user_id(@user)
        @schedule_default ||= ScheduleDefault.new 
        @schedule_default.weekday_hours ||= [0,0,0,0,0,0,0] 
        @schedule_default.user_id = @user.id
        
        @calendar = Redmine::Helpers::Calendar.new(Date.today, current_language, @period)
    end


    # Edit the schedule for the given week/user/project
    def edit
        @entries = get_entries
        @closed_entries = get_closed_entries
        render :layout => !request.xhr?
    end
    
    
    # Edit the schedule for the given week/user/project
    def fill
        render_404 if @project.nil?
        user_ids = visible_users(@projects.collect(&:members).flatten.uniq).collect { |user| user.id }
        @indexed_users = @users.index_by { |user| user.id }
        @defaults = get_defaults(user_ids).index_by { |default| default.user_id }
        @defaults.delete_if { |user_id, default| !default.weekday_hours.detect { |weekday| weekday != 0 }}
        @calendar = Redmine::Helpers::Calendar.new(Date.today, current_language, @period)
    end


    # 
    def report
        timelog_report
    end
    
    
    # This method is based off of Redmine's timelog. It has been modified
    # to accommodate the needs of the Schedules plugin. In the event that
    # changes are made to the original, this method will need to be updated
    # accordingly. As such, efforts should be made to modify this method as
    # little as possible as it's effectively a branch that we want to keep
    # in sync. 
    def details
      sort_init 'date', 'desc'
        sort_update 'date' => 'date',
                    'user' => 'user_id',
                    'project' => "#{Project.table_name}.name",
                    'hours' => 'hours'
        
        cond = ARCondition.new
        if @project.nil?
          cond << Project.allowed_to_condition(User.current, :view_schedules)
        end
        
        retrieve_date_range
        cond << ['date BETWEEN ? AND ?', @from, @to]
    
        ScheduleEntry.visible_by(User.current) do
          respond_to do |format|
            format.html {
              # Paginate results
              @entry_count = ScheduleEntry.count(:include => :project, :conditions => cond.conditions)
              @entry_pages = Paginator.new self, @entry_count, per_page_option, params['page']
              @entries = ScheduleEntry.find(:all, 
                                        :include => [:project, :user],
                                        :conditions => cond.conditions,
                                        :order => sort_clause,
                                        :limit  =>  @entry_pages.items_per_page,
                                        :offset =>  @entry_pages.current.offset)
              @total_hours = ScheduleEntry.sum(:hours, :include => :project, :conditions => cond.conditions).to_f
    
              render :layout => !request.xhr?
            }
            format.atom {
              entries = ScheduleEntry.find(:all,
                                       :include => [:project, :user],
                                       :conditions => cond.conditions,
                                       :order => "#{ScheduleEntry.table_name}.created_on DESC",
                                       :limit => Setting.feeds_limit.to_i)
              render_feed(entries, :title => l(:label_spent_time))
            }
            format.csv {
              # Export all entries
              @entries = ScheduleEntry.find(:all, 
                                        :include => [:project, :user],
                                        :conditions => cond.conditions,
                                        :order => sort_clause)
              send_data(entries_to_csv(@entries).read, :type => 'text/csv; header=present', :filename => 'timelog.csv')
            }
          end
        end
    end
    
    
    ############################################################################
    # Private methods
    ############################################################################
    private
    
    def load_params
        # Parse the given date or default to today
        @date = Date.parse(params[:date]) if params[:date]
        @date ||= Date.civil(params[:year].to_i, params[:month].to_i, params[:day].to_i) if params[:year] && params[:month] && params[:day]
        @date ||= Date.today
        @period = (params[:period] == "month") ? :month : :week
        if @period == :month
            @date = Date.civil(@date.year, @date.month, 1)
        end  
        @days_next = (@period == :week) ? 7 : Time.days_in_month(@date.month)
        @days_previous = 7
        @calendar = Redmine::Helpers::Calendar.new(@date, current_language, @period)
    end
    
    
    # Given a specific date, show the projects and users that the current user is
    # allowed to see and provide edit access to those permission is granted to.
    def save_entries
        if request.post? && params[:commit]
            save_scheduled_entries unless params[:schedule_entry].nil?
            save_closed_entries unless params[:schedule_closed_entry].nil?
            
            # If all entries saved without issue, view the results
            if flash[:warning].nil?
                flash[:notice] = l(:label_schedules_updated)
                if params[:commit] == l(:button_save_next)
                    redirect_to({:action => 'edit', :date => Date.parse(params[:date]) + @days_next, :period => @period})
                else
                    redirect_to({:action => 'index', :date => Date.parse(params[:date])})
                end
            else
                redirect_to({:action => 'edit', :date => Date.parse(params[:date])})
            end
        end
    end
    
    
    # Given a set of schedule entries, sift through them looking for changes in
    # the schedule. For each change, remove the old entry and save the new one
    # assuming sufficient access by the modifying user.
    def save_scheduled_entries
    
        # Get the users and projects involved in this save 
        user_ids = params[:schedule_entry].collect { |user_id, dates_projects_hours| user_id }
        users = User.find(:all, :conditions => "id IN ("+user_ids.join(',')+")").index_by { |user| user.id }
        project_ids = params[:schedule_entry].values.first.values.first.keys
        projects = Project.find(:all, :conditions => "id IN ("+project_ids.join(',')+")").index_by { |project| project.id }
        defaults = get_defaults(user_ids).index_by { |default| default.user_id }
        
        # Take a look at a user and their default schedule
        params[:schedule_entry].each do |user_id, dates_projects_hours|
            user = users[user_id.to_i]
            default = defaults[user.id]
            default ||= ScheduleDefault.new
            
            # Focus down on a specific day, determining the range we can work in
            dates_projects_hours.each do |date, projects_hours|
                date = Date.parse(date)
                restrictions = "date = '#{date}' AND user_id = #{user.id}"
                other_projects = " AND project_id NOT IN (#{projects_hours.collect {|ph| ph[0] }.join(',')})"
                available_hours = default.weekday_hours[date.wday]
                available_hours -= ScheduleEntry.sum(:hours, :conditions => restrictions + other_projects) if available_hours > 0
                closedEntry = ScheduleClosedEntry.find(:first, :conditions => restrictions) if available_hours > 0
                available_hours -= closedEntry.hours unless closedEntry.nil?
            
                # Look through the entries for each project, assuming access 
                entries = Array.new
                projects_hours.each do |project_id, hours|
                    project = projects[project_id.to_i]
                    if User.current.allowed_to?(:edit_all_schedules, project) || (User.current == user && User.current.allowed_to?(:edit_own_schedules, project)) || User.current.admin?

                        # Find the old schedule entry and create a new one
                        old_entry = ScheduleEntry.find(:first, :conditions => {:project_id => project_id, :user_id => user_id, :date => date})
                        new_entry = ScheduleEntry.new
                        new_entry.project_id = project.id
                        new_entry.user_id = user.id
                        new_entry.date = date
                        new_entry.hours = [hours.to_f, 0].max
                        entries << { :new => new_entry, :old => old_entry }
                        available_hours -= new_entry.hours
                    end
                end

                # Save the day's entries given enough time or access                
                if available_hours >= 0 || User.current == user || User.current.admin?
                    entries.each { |entry| save_entry(entry[:new], entry[:old], projects[entry[:new].project.id]) }
                else  
                    flash[:warning] = l(:error_schedules_insufficient_availability)
                end
            end
        end
    end
    
    
    # Given a new schedule entry and the entry that it replaces, save the first
    # and delete the second. Send out a notification if necessary.  
    def save_entry(new_entry, old_entry, project)
        if old_entry.nil? || new_entry.hours != old_entry.hours
        
            # Send mail if editing another user
            if (User.current != new_entry.user) && (params[:notify]) && (new_entry.user.allowed_to?(:view_schedules, project))
                ScheduleMailer.deliver_future_changed(User.current, new_entry.user, new_entry.project, new_entry.date, new_entry.hours) 
            end
            
            # Save the changes
            new_entry.save if new_entry.hours > 0
            old_entry.destroy unless old_entry.nil?
        end
    end
    
    
    # Save schedule closed entries if the owning user or an admin is requesting
    # the change.
    def save_closed_entries

        # Get the users and projects involved in this save 
        user_ids = params[:schedule_closed_entry].collect { |user_id, dates| user_id }
        users = User.find(:all, :conditions => "id IN ("+user_ids.join(',')+")").index_by { |user| user.id }
    
        # Save the user/day/hours triplet assuming sufficient access
        params[:schedule_closed_entry].each do |user_id, dates|
            user = users[user_id.to_i]
            if (User.current == user) || User.current.admin?
                dates.each do |date, hours|
                    old_entry = ScheduleClosedEntry.find(:first, :conditions => {:user_id => user_id, :date => date})
                    new_entry = ScheduleClosedEntry.new
                    new_entry.user_id = user.id
                    new_entry.date = date
                    new_entry.hours = hours.to_f
                    new_entry.save if new_entry.hours > 0
                    old_entry.destroy unless old_entry.nil?
                end
            end
        end
    end


    # Save the given default availability if one was provided    
    def save_default
        find_user
        if request.post? && params[:commit]
        
            # Determine the user's current availability default
            @schedule_default = ScheduleDefault.find_by_user_id(@user.id)
            @schedule_default ||= ScheduleDefault.new 
            @schedule_default.weekday_hours ||= [0,0,0,0,0,0,0] 
            @schedule_default.user_id = @user.id
            
            # Save the new default
            @schedule_default.weekday_hours = params[:schedule_default].sort.collect { |a,b| [b.to_f, 0.0].max }
            @schedule_default.save
            
            # Inform the user that the update was successful 
            flash[:notice] = l(:notice_successful_update)
            redirect_to({:action => 'index', :user_id => @user.id})
        end
    end
    
    
    # Fills user schedules up to a specified number of hours
    def fill_entries
        if request.post?
            
            # Get the defaults for the users we want to fill time for
            params[:fill_total].delete_if { |user_id, fill_total| fill_total.to_f == 0 }
            defaults = get_defaults(params[:fill_total].collect { |user_id, fill_total| user_id.to_i }).index_by { |default| default.user_id }

            # Fill the schedule of each specified user
            params[:fill_total].each do |user_id, fill_total|
                
                # Prepare variables for looping 
                hours_remaining = fill_total.to_f
                user_id = user_id.to_i
                default = defaults[user_id].weekday_hours
                date_index = @date
                
                # Iterate through days until we've filled up enough
                while hours_remaining > 0
                    fill_hours = params[:fill_entry][user_id.to_s][date_index.wday.to_s].to_f
                    if fill_hours > 0 && default[date_index.wday] > 0
                    
                        # Find entries for this day
                        restrictions = "date = '#{date_index}' AND user_id = #{user_id}"
                        project_entry = ScheduleEntry.find(:first, :conditions => restrictions + " AND project_id = #{@project.id}")
                        other_project_hours = ScheduleEntry.sum(:hours, :conditions => restrictions + " AND project_id <> #{@project.id}")
                        closed_hours = ScheduleClosedEntry.sum(:hours, :conditions => restrictions)
                    
                        # Determine the number of hours available
                        available_hours = default[date_index.wday]
                        available_hours -= closed_hours
                        available_hours -= other_project_hours
                        available_hours -= project_entry.hours unless project_entry.nil?
                        available_hours = [available_hours, fill_hours, hours_remaining].min
                        available_hours = 0 if date_index.holiday?($holiday_locale, :observed)

                        # Create an entry if we're adding time to this day
                        if available_hours > 0 
                            new_entry = ScheduleEntry.new
                            new_entry.project_id = @project.id
                            new_entry.user_id = user_id
                            new_entry.date = date_index
                            new_entry.hours = available_hours
                            new_entry.hours += project_entry.hours unless project_entry.nil?
                            save_entry(new_entry, project_entry, @project.id)
                            hours_remaining -= available_hours
                        end
                    end
                    date_index += 1
                end
            end
                    
            # Inform the user that the update was successful 
            flash[:notice] = l(:notice_successful_update)
            redirect_to({:action => 'index', :project_id => @project.id})
        end
    end
    
    
    # Get schedule entries between two dates for the specified users and projects
    def get_entries(project_restriction = true, startdt = @calendar.startdt, enddt = @calendar.enddt, ignore_project = false)
        restrictions = "(date BETWEEN '#{startdt}' AND '#{enddt}')"
        restrictions << " AND user_id = " + @user.id.to_s unless @user.nil?
        if project_restriction
            restrictions << " AND project_id IN ("+@projects.collect {|project| project.id.to_s }.join(',')+")" unless @projects.empty?
            restrictions << " AND project_id = " + @project.id.to_s unless @project.nil?
        elsif ignore_project
            restrictions << " AND project_id <> #{@project.id}"
        end
        ScheduleEntry.find(:all, :conditions => restrictions)
    end
    
    
    # Get closed entries between two dates for the specified users
    def get_closed_entries(startdt = @calendar.startdt, enddt = @calendar.enddt)
        restrictions = "(date BETWEEN '#{startdt}' AND '#{enddt}')"
        restrictions << " AND user_id IN ("+@users.collect {|user| user.id.to_s }.join(',')+")" unless @users.empty?
        ScheduleClosedEntry.find(:all, :conditions => restrictions)
    end
    
    
    # Get schedule defaults for the specified users
    def get_defaults(user_ids = nil)
        restrictions = "user_id IN ("+@users.collect {|user| user.id.to_s }.join(',')+")" unless @users.empty?
        restrictions = "user_id IN ("+user_ids.join(',')+")" unless user_ids.nil?
        ScheduleDefault.find(:all, :conditions => restrictions)
    end
    
    
    # Get availability entries between two dates for the specified users
    def get_availabilities(startdt = @calendar.startdt, enddt = @calendar.enddt, ignore_project = false)

        # Get the user's scheduled entries
        entries_by_user = get_entries(false, startdt, enddt, ignore_project).group_by{ |entry| entry.user_id }
        entries_by_user.each { |user_id, user_entries| entries_by_user[user_id] = user_entries.group_by { |entry| entry.date } }
        
        # Get the user's scheduled unavailabilities
        closed_entries_by_user = get_closed_entries(startdt, enddt).group_by { |closed_entry| closed_entry.user_id }
        closed_entries_by_user.each { |user_id, user_entries| closed_entries_by_user[user_id] = user_entries.index_by { |entry| entry.date } }

        # Get the user's default availability
        defaults_by_user = get_defaults.index_by { |default| default.user.id }

        # Generate and return the availabilities based on the above variables 
        availabilities = Hash.new
        (startdt..enddt).each do |day|
            availabilities[day] = Hash.new
            @users.each do |user|
                availabilities[day][user.id] = 0
                availabilities[day][user.id] = defaults_by_user[user.id].weekday_hours[day.wday] unless defaults_by_user[user.id].nil?
                availabilities[day][user.id] -= entries_by_user[user.id][day].collect {|entry| entry.hours }.sum unless entries_by_user[user.id].nil? || entries_by_user[user.id][day].nil?
                availabilities[day][user.id] -= closed_entries_by_user[user.id][day].hours unless closed_entries_by_user[user.id].nil? || closed_entries_by_user[user.id][day].nil?
                availabilities[day][user.id] = [0, availabilities[day][user.id]].max
                availabilities[day][user.id] = 0 if day.holiday?($holiday_locale, :observed)
            end
        end
        availabilities
    end
    
    #
    def find_user
        params[:user_id] = User.current.id if params[:user_id].nil?
        deny_access unless User.current.id == params[:user_id].to_i || User.current.admin?
        @user = User.find(params[:user_id])
    rescue ActiveRecord::RecordNotFound
        render_404
    end
        
    # Find the project associated with the given version
    def find_project_by_version
        @version = Version.find(params[:id])
        @project = @version.project
        deny_access unless User.current.allowed_to?(:edit_all_schedules, @project) && User.current.allowed_to?(:manage_versions, @project)
    rescue ActiveRecord::RecordNotFound
        render_404
    end
    
    #
    def find_users_and_projects
    
        # Parse the focused user and/or project 
        @project = Project.find(params[:project_id]) if params[:project_id]
        @user = User.find(params[:user_id]) if params[:user_id]
        @focus = "users" if @project.nil? && @user.nil?
        @projects = visible_projects.sort
        @projects = @projects & @user.projects unless @user.nil?
        @projects = @projects & [@project] unless @project.nil?
        @users = visible_users(@projects.collect(&:members).flatten.uniq)
        @users = @users & [@user] unless @user.nil?
        @users = [@user] if !@user.nil? && @users.empty? && User.current.admin?
        deny_access if (@projects.empty? || @users.nil? || @users.empty?) && !User.current.admin?
        
    rescue ActiveRecord::RecordNotFound
        render_404
    end
    
    
    ############################################################################
    # Instance method interfaces to class methods
    ############################################################################
    def visible_projects
        self.class.visible_projects
    end
    def visible_users(members)        
        self.class.visible_users(members)
    end
end

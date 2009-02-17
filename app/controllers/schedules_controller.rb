class SchedulesController < ApplicationController

	# Initialize the controller
	before_filter :require_login
	before_filter :save_entries, :only => [:edit]
	include SchedulesHelper


	# Given a specific month, show the projects and users that the current user is
	# allowed to see and provide links to edit based on specific dates, projects or
	# users.
	def index
		# Determine if we're looking at a specific user or project
		@project = Project.find(params[:project_id]) if params[:project_id]
		@user = User.find(params[:user_id]) if params[:user_id] 
	
		# Initialize the calendar helper
		@date = Date.parse(params[:date]) if params[:date]
		@date ||= Date.civil(params[:year].to_i, params[:month].to_i, params[:day].to_i) if params[:year] && params[:month] && params[:day]
		@date ||= Date.today
		@calendar = Redmine::Helpers::Calendar.new(Date.civil(@date.year, @date.month, @date.day), current_language, :week)
		
		# Retrieve the associated schedule_entries
		@projects = visible_projects
		if @projects.size > 0
			common_restrictions = "(date BETWEEN '#{@calendar.startdt}' AND '#{@calendar.enddt}')"
			common_restrictions << " AND user_id = " + params[:user_id] if params[:user_id]
			schedule_restrictions = " AND project_id IN ("+@projects.collect {|project| project.id.to_s }.join(',')+")"
			schedule_restrictions << " AND project_id = " + @project.id.to_s unless @project.nil?
			availability_restrictions = " AND true"
			availability_restrictions << " AND user_id IN ("+@project.members.collect {|member| member.user.id.to_s }.join(',')+")" unless @project.nil?
			@schedule_entries = SchedulesCalendar.new(ScheduleEntry.find(:all, :conditions => common_restrictions + schedule_restrictions))
			@availability_entries = SchedulesCalendar.new(AvailabilityEntry.find(:all, :conditions => common_restrictions + availability_restrictions))
			render :action => 'index', :layout => false if request.xhr?
			render :action => 'index' unless request.xhr?
		else
			render_403
		end
	end
	
	# View only the times in which users are available
	def available
		@viewing_availability = true 
		index
	end
	

	# Given a specific day, user or project, show the complementary rows and columns
	# and provide input fields for each coordinate cell. If the current user doesn't
	# have access to a row or column it shouldn't display. Likewise, if the current
	# user can only view a cell, display it as disabled.
	def edit
		# Get specified user or project, if any
		@project = Project.find(params[:project_id]) if params[:project_id]
		@projects = [@project] if params[:project_id]
		@user = User.find(params[:user_id]) if params[:user_id]
		@users = [@user] if params[:user_id]
		
		# If no user or project was specified, determine them
		@projects = @user.nil? ? visible_projects : @user.projects if @projects.nil?
		@projects = @projects & visible_projects
		if @user.nil?
			@users = @projects.collect(&:users).flatten.uniq
		end
		
		# If we couldn't find any users or projects, then we don't have access
		if @projects.size == 0 || @users.size == 0
			render_403
			return
		end
		
		# Sort the projects and users
		@projects = @projects.sort
		@users = @users.sort
		
		# Parse the given date
		@date = Date.parse(params[:date]) if params[:date]
		@date ||= Date.civil(params[:year].to_i, params[:month].to_i, params[:day].to_i) if params[:year] && params[:month] && params[:day]
		@date ||= Date.today
		@date = Date.civil(@date.year, @date.month, @date.day - @date.wday) if @user || @project
		
		# Initialize the necessary helpers
		@calendar = Redmine::Helpers::Calendar.new(@date, current_language, :week) if @user.nil? || @project.nil?
		@calendar = Redmine::Helpers::Calendar.new(@date, current_language) unless @user.nil? || @project.nil?

		# Render the page
		render :layout => !request.xhr?
	end
	
		
	private
	
	
	# Given a specific date, show the projects and users that the current user is
	# allowed to see and provide edit access to those permission is granted to.
	def save_entries
		if request.post? && params[:commit]
			save_schedule_entries unless params[:schedule_entry].nil?
			save_availability_entries unless params[:availability_entry].nil?
			flash[:notice] = l(:label_schedules_updated)
			redirect_to({:action => 'index', :date => Date.parse(params[:date])})
		end
	end


	#
	def save_schedule_entries
		params[:schedule_entry].each do |user_id, project_ids|
			user = User.find(user_id)
			project_ids.each do |project_id, dates|
				project = Project.find(project_id)
				if User.current.allowed_to?(:edit_all_schedules, project) || (User.current == user && User.current.allowed_to?(:edit_own_schedules, project)) || User.current.admin?
					dates.each do |date, hours|
					
						# Parse the given parameters
						date = Date.parse(date)
						hours = hours.to_f

						# Find the old schedule entry and create a new one
						old_schedule_entry = ScheduleEntry.find(:first, :conditions => {:project_id => project_id, :user_id => user_id, :date => date})
						new_schedule_entry = ScheduleEntry.new
						new_schedule_entry.project_id = project_id
						new_schedule_entry.user_id = user_id
						new_schedule_entry.date = date
						new_schedule_entry.hours = hours
						new_schedule_entry.save if new_schedule_entry.hours > 0
						
						# Find the old availability entry and create a new one
						old_availability_entry = AvailabilityEntry.find(:first, :conditions => {:user_id => user_id, :date => date})
						new_availability_entry = AvailabilityEntry.new
						new_availability_entry.user_id = user_id
						new_availability_entry.date = date
						new_availability_entry.hours = (old_availability_entry.nil? ? 0 : old_availability_entry.hours)
						new_availability_entry.hours += (old_schedule_entry.nil? ? 0 : old_schedule_entry.hours)
						new_availability_entry.hours -= new_schedule_entry.hours
						new_availability_entry.save if new_availability_entry.hours > 0
						
						# Send mail if editing another user
						if (User.current != user) && (params[:notify]) && (old_schedule_entry.nil? || hours != old_schedule_entry.hours) && (user.allowed_to?(:view_schedules, project))
							ScheduleMailer.deliver_future_changed(User.current, user, project, date, hours) 
						end
						
						# Destroy the old entries
						old_schedule_entry.destroy unless old_schedule_entry.nil?
						old_availability_entry.destroy unless old_availability_entry.nil?
					end
				end
			end
		end
	end
	
	
	#
	def save_availability_entries
		params[:availability_entry].each do |user_id, dates|
			user = User.find(user_id)
			if (User.current == user || User.current.admin?)
				dates.each do |date, hours|
				
					# Find the old entry and create a new one
					old_entry = AvailabilityEntry.find(:first, :conditions => {:user_id => user_id, :date => date})
					new_entry = AvailabilityEntry.new
					new_entry.user_id = user_id
					new_entry.date = Date.parse(date)
					new_entry.hours = hours.to_f
					new_entry.save if new_entry.hours > 0
					
					# Send mail if editing another user
					# DISABLED FOR NOW
					
					# Destroy the old entry
					old_entry.destroy unless old_entry.nil?
				end
			end
		end
	end
	
	
	# Return a list of the projects the user has permission to view schedules in
	def visible_projects
		Project.find(:all, :conditions => Project.allowed_to_condition(User.current, :view_schedules))
	end
end
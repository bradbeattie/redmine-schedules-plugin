class ScheduleEntry < ActiveRecord::Base

	belongs_to :project
	belongs_to :user
	
	def form_id
		"schedule_entry[#{user_id}][#{project_id}][#{date}]" 
	end
	
	def <=>(other)
		if self.project != other.project
			self.project <=> other.project
		else
			self.user <=> other.user
		end
	end
	
##----------------------------------------------------------------------------##
	# These methods are based off of Redmine's timelog. They have been
	# modified to accommodate the needs of the Schedules plugin. In the
	# event that changes are made to the original, these methods will need
	# to be updated accordingly. As such, efforts should be made to modify
	# these methods as little as possible as they're effectively a branch
	# that we want to keep in sync.
	
	def self.visible_by(usr)
		with_scope(:find => { :conditions => Project.allowed_to_condition(usr, :view_schedules) }) do
			yield
		end
	end
    
	# Returns true if the time entry can be edited by usr, otherwise false
	def editable_by?(usr)
		(usr == user && usr.allowed_to?(:edit_own_schedules, project)) || usr.allowed_to?(:edit_all_schedules, project)
	end
##----------------------------------------------------------------------------##
 	
end

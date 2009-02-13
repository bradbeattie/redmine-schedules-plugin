module SchedulesHelper
	class SchedulesCalendar
	
		def initialize(schedule_entries)
			@schedule_entries_by_day = schedule_entries.group_by {|schedule_entry| schedule_entry.date}
			@schedule_entries_by_user = schedule_entries.group_by {|schedule_entry| schedule_entry.user}
			@schedule_entries_by_project = schedule_entries.group_by {|schedule_entry| schedule_entry.project}
		end
	      
		# Returns events for the given day
		def schedule_entries_by_day(day)
			(@schedule_entries_by_day[day] || [])
		end
		
		# Returns events for the given project
		def schedule_entries_by_project(project)
			(@schedule_entries_by_project[project] || [])
		end
		
		# Returns events for the given user
		def schedule_entries_by_user(user)
			(@schedule_entries_by_user[user] || [])
		end

		def projects
			@schedule_entries_by_project.keys
		end
	end
end

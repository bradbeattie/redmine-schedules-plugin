module SchedulesHelper
	class SchedulesCalendar
	
		def initialize(entries)
			@entries_by_day = entries.group_by {|entry| entry.date}
		end
	      
		# Returns events for the given day
		def entries_by_day(day)
			(@entries_by_day[day] || [])
		end
	end
end

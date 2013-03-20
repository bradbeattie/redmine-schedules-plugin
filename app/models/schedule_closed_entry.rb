class ScheduleClosedEntry < ActiveRecord::Base

    belongs_to :user
    
    def form_id
        "schedule_closed_entry[#{user_id}][#{date}]" 
    end
    
end

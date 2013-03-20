class ScheduleDefault < ActiveRecord::Base

    belongs_to :user
    serialize :weekday_hours
    validates_uniqueness_of :user_id
    
    def initialize
        super
        self.weekday_hours = [0,0,0,0,0,0,0]
    end
end

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
	
	def style(color_users)
		result = "height: "
		result << (hours < 2.4 ? 2.4 : hours).to_s
		result << "em; "
		
		color_id = color_users ? user.id : project.id
		red   = ((Math.sin(color_id*2.6+Math::PI*0/3)+5)*32).to_i + 56
		green = ((Math.sin(color_id*2.6+Math::PI*2/3)+5)*32).to_i + 56
		blue  = ((Math.sin(color_id*2.6+Math::PI*4/3)+5)*32).to_i + 56
		
		result << "background: rgb(#{red.to_s},#{green.to_s},#{blue.to_s}); "
		result << "border: 1px solid rgb(#{(red/2).to_s},#{(green/2).to_s},#{(blue/2).to_s}); "
		
		result 
	end
end

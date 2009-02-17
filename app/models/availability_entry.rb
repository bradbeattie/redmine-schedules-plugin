class AvailabilityEntry < ActiveRecord::Base

	belongs_to :user
	
	def form_id
		"availability_entry[#{user_id}][#{date}]"
	end
	
	def <=>(other)
		self.user <=> other.user
	end
	
	def style(color_users, transparent)
	
		result = "height: "
		result << (hours < 2.4 ? 2.4 : hours).to_s
		result << "em; "
		
		if (color_users)
			red   = ((Math.sin(user.id*2.6+Math::PI*0/3)+5)*32).to_i + 56
			green = ((Math.sin(user.id*2.6+Math::PI*2/3)+5)*32).to_i + 56
			blue  = ((Math.sin(user.id*2.6+Math::PI*4/3)+5)*32).to_i + 56
		else
			red, green, blue = 216, 216, 216
		end

		result << "opacity: 0.5; " if transparent
		result << "background: rgb(#{red.to_s},#{green.to_s},#{blue.to_s}); "
		result << "border: 1px solid rgb(#{(red/2).to_s},#{(green/2).to_s},#{(blue/2).to_s}); "
		
		result 
	end
end

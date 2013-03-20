class ScheduleMailer < Mailer
    def future_changed(user_source, user_target, project, date, hours)
        recipients user_target.mail
        subject "Schedule changed"

        body(
            :user => user_source,
            :project => project,
            :date => date,
            :hours => hours
        )
    end
end
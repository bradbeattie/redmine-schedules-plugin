# Wrappers around the Redmine core API changes between versions
module ScheduleCompatibility
  class I18n
    if Redmine.const_defined?(:I18n)
      include ::Redmine::I18n
    end

    # Wraps either the I18n.l() from Redmine or GLoc.lwr() from 0.8.x
    def self.lwr(*arguments)
      if Redmine.const_defined?(:I18n)
        l(*arguments)
      else
        # Extract the Hash value out and into a standard decimal for GLoc
        label, value = *arguments
        GLoc.lwr(label, value[:value])
      end
    end

    def self.l_hours(*arguments)
      if Redmine.const_defined?(:I18n)
        super
      else
        GLoc.lwr(:label_f_hour, *arguments)
      end
    end
  end
end

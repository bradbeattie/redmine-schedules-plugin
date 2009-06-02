    # This file is based off of Redmine's timelog. It has been modified
    # to accommodate the needs of the Schedules plugin. In the event that
    # changes are made to the original, this file will need to be updated
    # accordingly. As such, efforts should be made to modify this file as
    # little as possible as it's effectively a branch that we want to keep
    # in sync.

module SchedulesHelper
    include ApplicationHelper

    def timelog_report
        @available_criterias = {
            'project' => {:sql => "project_id", :klass => Project, :label => :label_project},
            'member'  => {:sql => "user_id",    :klass => User,    :label => :label_member}
        }
        
        @criterias = params[:criterias] || []
        @criterias = @criterias.select{|criteria| @available_criterias.has_key? criteria}
        @criterias.uniq!
        @criterias = @criterias[0,3]
        
        @columns = (params[:columns] && %w(year month week day).include?(params[:columns])) ? params[:columns] : 'month'
        
        retrieve_date_range
        
        unless @criterias.empty?
            sql_outer_select = @criterias.join(', ')
            sql_inner_select = @criterias.collect{|criteria| @available_criterias[criteria][:sql] + " AS " + criteria}.join(', ')
            sql_group_by = @criterias.join(', ')
            
            sql = "SELECT #{sql_outer_select}, tyear, tmonth, tweek, date, SUM(hours) AS hours, SUM(logged_hours) AS logged_hours FROM ("
            sql << "SELECT #{sql_inner_select}, YEAR(date) AS tyear, MONTH(date) AS tmonth, WEEK(date, 1) AS tweek, date, schedule_entries.hours AS hours, null AS logged_hours"
            sql << " FROM #{ScheduleEntry.table_name}"
            sql << " LEFT JOIN #{Project.table_name} ON #{ScheduleEntry.table_name}.project_id = #{Project.table_name}.id"
            sql << " WHERE"
            sql << " (%s) AND" % @project.project_condition(Setting.display_subprojects_issues?) if @project
            sql << " (%s) AND" % Project.allowed_to_condition(User.current, :view_schedules)
            sql << " (date BETWEEN '%s' AND '%s')" % [ActiveRecord::Base.connection.quoted_date(@from.to_time), ActiveRecord::Base.connection.quoted_date(@to.to_time)]
            sql << " UNION "
            sql << "SELECT #{sql_inner_select}, tyear, tmonth, tweek, spent_on AS date, null AS hours, sum(time_entries.hours) AS logged_hours"
            sql << " FROM #{TimeEntry.table_name}"
            sql << " LEFT JOIN #{Project.table_name} ON #{TimeEntry.table_name}.project_id = #{Project.table_name}.id"
            sql << " WHERE"
            sql << " (%s) AND" % @project.project_condition(Setting.display_subprojects_issues?) if @project
            sql << " (%s) AND" % Project.allowed_to_condition(User.current, :view_schedules)
            sql << " (spent_on BETWEEN '%s' AND '%s')" % [ActiveRecord::Base.connection.quoted_date(@from.to_time), ActiveRecord::Base.connection.quoted_date(@to.to_time)]
            sql << " GROUP BY #{sql_group_by}, date"
            sql << ") AS tbl GROUP BY #{sql_group_by}, tyear, tmonth, tweek, date"
          
            @hours = ActiveRecord::Base.connection.select_all(sql)
            
            @hours.each do |row|
                case @columns
                when 'year'
                    row['year'] = row['tyear']
                when 'month'
                    row['month'] = "#{row['tyear']}-#{row['tmonth']}"
                when 'week'
                    row['week'] = "#{row['tyear']}-#{row['tweek']}"
                when 'day'
                    row['day'] = "#{row['date']}"
                end
            end
            
            @total_hours = @hours.inject(0) {|s,k| s = s + k['hours'].to_f}
            
            @periods = []
            # Date#at_beginning_of_ not supported in Rails 1.2.x
            date_from = @from.to_time
            # 100 columns max
            while date_from <= @to.to_time && @periods.length < 100
                case @columns
                when 'year'
                    @periods << "#{date_from.year}"
                    date_from = (date_from + 1.year).at_beginning_of_year
                when 'month'
                    @periods << "#{date_from.year}-#{date_from.month}"
                    date_from = (date_from + 1.month).at_beginning_of_month
                when 'week'
                    @periods << "#{date_from.year}-#{date_from.to_date.cweek}"
                    date_from = (date_from + 7.day).at_beginning_of_week
                when 'day'
                    @periods << "#{date_from.to_date}"
                    date_from = date_from + 1.day
                end
            end
        end
        
        respond_to do |format|
            format.html { render :layout => !request.xhr? }
            format.csv  { send_data(report_to_csv(@criterias, @periods, @hours).read, :type => 'text/csv; header=present', :filename => 'timelog.csv') }
        end
    end
  
  def select_hours(data, criteria, value)
      data.select {|row| row[criteria] == value}
  end
  
  def sum_hours(data)
      sum = 0
      data.each do |row|
          sum += row['hours'].to_f
      end
      sum
  end
  
  def sum_logged_hours(data)
      sum = 0
      data.each do |row|
          sum += row['logged_hours'].to_f
      end
      sum
  end
  
  def options_for_period_select(value)
      options_for_select([[l(:label_all_time), 'all'],
                          [l(:label_today), 'today'],
                          [l(:label_yesterday), 'yesterday'],
                          [l(:label_this_week), 'current_week'],
                          [l(:label_last_week), 'last_week'],
                          [l(:label_last_n_days, 7), '7_days'],
                          [l(:label_this_month), 'current_month'],
                          [l(:label_last_month), 'last_month'],
                          [l(:label_last_n_days, 30), '30_days'],
                          [l(:label_this_year), 'current_year']],
                          value)
  end
  
  def entries_to_csv(entries)
      ic = Iconv.new(l(:general_csv_encoding), 'UTF-8')    
      decimal_separator = l(:general_csv_decimal_separator)
      export = StringIO.new
      CSV::Writer.generate(export, l(:general_csv_separator)) do |csv|
          # csv header fields
          headers = [l(:field_date),
                     l(:field_user),
                     l(:field_project),
                     l(:field_hours),
                     ]
          
          csv << headers.collect {|c| begin; ic.iconv(c.to_s); rescue; c.to_s; end }
          # csv lines
          entries.each do |entry|
              fields = [format_date(entry.date),
                        entry.user,
                        entry.project,
                        entry.hours.to_s.gsub('.', decimal_separator),
                        ]
                      
            csv << fields.collect {|c| begin; ic.iconv(c.to_s); rescue; c.to_s; end }
          end
      end
      export.rewind
      export
  end
  
  def format_criteria_value(criteria, value)
      value.blank? ? l(:label_none) : ((k = @available_criterias[criteria][:klass]) ? k.find_by_id(value.to_i) : format_value(value, @available_criterias[criteria][:format]))
  end
  
  def report_to_csv(criterias, periods, hours)
      export = StringIO.new
      CSV::Writer.generate(export, l(:general_csv_separator)) do |csv|
          # Column headers
          headers = criterias.collect {|criteria| l(@available_criterias[criteria][:label]) }
          headers += periods
          headers << l(:label_total)
          csv << headers.collect {|c| to_utf8(c) }
          # Content
          report_criteria_to_csv(csv, criterias, periods, hours)
          # Total row
          row = [ l(:label_total) ] + [''] * (criterias.size - 1)
          total = 0
          periods.each do |period|
              sum = sum_hours(select_hours(hours, @columns, period.to_s))
              total += sum
              row << (sum > 0 ? "%.2f" % sum : '')
          end
          row << "%.2f" %total
          csv << row
      end
      export.rewind
      export
  end
  
  def report_criteria_to_csv(csv, criterias, periods, hours, level=0)
      hours.collect {|h| h[criterias[level]].to_s}.uniq.each do |value|
          hours_for_value = select_hours(hours, criterias[level], value)
          next if hours_for_value.empty?
          row = [''] * level
          row << to_utf8(format_criteria_value(criterias[level], value))
          row += [''] * (criterias.length - level - 1)
          total = 0
          periods.each do |period|
              sum = sum_hours(select_hours(hours_for_value, @columns, period.to_s))
              total += sum
              row << (sum > 0 ? "%.2f" % sum : '')
          end
          row << "%.2f" %total
          csv << row
          
          if criterias.length > level + 1
              report_criteria_to_csv(csv, criterias, periods, hours_for_value, level + 1)
          end
      end
  end
  
  def to_utf8(s)
      @ic ||= Iconv.new(l(:general_csv_encoding), 'UTF-8')
      begin; @ic.iconv(s.to_s); rescue; s.to_s; end
  end
  
  
      # Retrieves the date range based on predefined ranges or specific from/to param dates
  def retrieve_date_range
      @free_period = false
      @from, @to = nil, nil
  
      if params[:period_type] == '1' || (params[:period_type].nil? && !params[:period].nil?)
          case params[:period].to_s
          when 'today'
              @from = @to = Date.today
          when 'yesterday'
              @from = @to = Date.today - 1
          when 'current_week'
              @from = Date.today - (Date.today.cwday - 1)%7
              @to = @from + 6
          when 'last_week'
              @from = Date.today - 7 - (Date.today.cwday - 1)%7
              @to = @from + 6
          when '7_days'
              @from = Date.today - 7
              @to = Date.today
          when 'current_month'
              @from = Date.civil(Date.today.year, Date.today.month, 1)
              @to = (@from >> 1) - 1
          when 'last_month'
              @from = Date.civil(Date.today.year, Date.today.month, 1) << 1
              @to = (@from >> 1) - 1
          when '30_days'
              @from = Date.today - 30
              @to = Date.today
          when 'current_year'
              @from = Date.civil(Date.today.year, 1, 1)
              @to = Date.civil(Date.today.year, 12, 31)
          end
      elsif params[:period_type] == '2' || (params[:period_type].nil? && (!params[:from].nil? || !params[:to].nil?))
          begin; @from = params[:from].to_s.to_date unless params[:from].blank?; rescue; end
          begin; @to = params[:to].to_s.to_date unless params[:to].blank?; rescue; end
          @free_period = true
      else
          # default
      end
      
      @from, @to = @to, @from if @from && @to && @from > @to
      
      schedule_entry_minimum = ScheduleEntry.minimum(:date, :include => :project, :conditions => Project.allowed_to_condition(User.current, :view_schedules))
      schedule_entry_maximum = ScheduleEntry.maximum(:date, :include => :project, :conditions => Project.allowed_to_condition(User.current, :view_schedules))
      time_entry_minimum = TimeEntry.minimum(:spent_on, :include => :project, :conditions => Project.allowed_to_condition(User.current, :view_time_entries))
      time_entry_maximum = TimeEntry.maximum(:spent_on, :include => :project, :conditions => Project.allowed_to_condition(User.current, :view_time_entries))
      minimums = [Date.today, schedule_entry_minimum, time_entry_minimum].compact.sort;
      maximums = [Date.today, schedule_entry_maximum, time_entry_maximum].compact.sort;
      @from ||= minimums.first - 1
      @to   ||= maximums.last
  end
  
      
  def find_optional_project
      if !params[:project_id].blank?
          @project = Project.find(params[:project_id])
      end
      deny_access unless User.current.allowed_to?(:view_schedules, @project, :global => true)
  end

end

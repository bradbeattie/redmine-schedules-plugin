	# This file is based off of Redmine's timelog. It has been modified
	# to accommodate the needs of the Schedules plugin. In the event that
	# changes are made to the original, this file will need to be updated
	# accordingly. As such, efforts should be made to modify this file as
	# little as possible as it's effectively a branch that we want to keep
	# in sync.

module SchedulesHelper
  include ApplicationHelper
  
  def render_timelog_breadcrumb
    links = []
    links << link_to(l(:label_project_all), {:project_id => nil, :issue_id => nil})
    links << link_to(h(@project), {:project_id => @project, :issue_id => nil}) if @project
    links << link_to_issue(@issue) if @issue
    breadcrumb links
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
end

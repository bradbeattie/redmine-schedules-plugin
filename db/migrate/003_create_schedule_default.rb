class CreateScheduleDefault < ActiveRecord::Migration
  def self.up
    create_table :schedule_defaults do |t|
      t.column :user_id, :integer, :default => 0, :null => false
      t.column :weekday_hours, :text
    end
    add_index "schedule_defaults", ["user_id"], :name => "schedule_defaults_user_id"

    create_table :schedule_closed_entries do |t|
      t.column :user_id, :integer, :default => 0, :null => false
      t.column :date, :date, :null => false
      t.column :hours, :float, :null => false
      t.column :comment, :text
    end
    
    add_index "schedule_closed_entries", ["user_id"], :name => "schedule_closed_entries_user_id"
    add_index "schedule_closed_entries", ["date"], :name => "schedule_closed_entries_date"
  end

  def self.down
    drop_table :schedule_closed_entries
    drop_table :schedule_defaults
  end
end

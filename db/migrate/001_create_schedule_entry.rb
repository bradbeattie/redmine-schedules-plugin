class CreateScheduleEntry < ActiveRecord::Migration
  def self.up
    create_table :schedule_entries do |t|
      t.column :user_id, :integer, :default => 0, :null => false
      t.column :project_id, :integer, :default => 0, :null => false
      t.column :date, :date, :null => false
      t.column :hours, :float, :null => false
    end
    
    add_index "schedule_entries", ["project_id"], :name => "schedule_entries_project_id"
    add_index "schedule_entries", ["user_id"], :name => "schedule_entries_user_id"
    add_index "schedule_entries", ["date"], :name => "schedule_entries_date"
  end

  def self.down
    drop_table :schedule_entries
  end
end

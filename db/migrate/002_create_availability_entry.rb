class CreateAvailabilityEntry < ActiveRecord::Migration
  def self.up
    create_table :availability_entries do |t|
      t.column :user_id, :integer, :default => 0, :null => false
      t.column :date, :date, :null => false
      t.column :hours, :float, :null => false
    end
    
    add_index "availability_entries", ["user_id"], :name => "availability_entries_user_id"
    add_index "availability_entries", ["date"], :name => "availability_entries_date"
  end

  def self.down
    drop_table :availability_entries
  end
end

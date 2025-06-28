class CreateBusinessActivityLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :business_activity_logs do |t|
      t.string :activity_type, null: false, index: true
      t.string :entity_type, index: true
      t.integer :entity_id, index: true
      t.string :user_id, index: true
      t.string :operation_name
      t.string :metric_name
      t.decimal :metric_value, precision: 15, scale: 4
      t.text :context
      t.datetime :performed_at, null: false, index: true
      
      t.timestamps
    end
    
    # Composite indexes for common queries
    add_index :business_activity_logs, [:entity_type, :entity_id], name: 'index_business_activity_logs_on_entity'
    add_index :business_activity_logs, [:activity_type, :performed_at], name: 'index_business_activity_logs_on_type_and_time'
    add_index :business_activity_logs, [:user_id, :performed_at], name: 'index_business_activity_logs_on_user_and_time'
    add_index :business_activity_logs, [:performed_at, :activity_type], name: 'index_business_activity_logs_on_time_and_type'
  end
end
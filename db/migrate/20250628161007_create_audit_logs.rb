class CreateAuditLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :audit_logs do |t|
      t.string :auditable_type
      t.integer :auditable_id
      t.string :action
      t.text :audit_data

      t.timestamps
    end
  end
end

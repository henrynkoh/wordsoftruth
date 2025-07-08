class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :provider, null: false
      t.string :uid, null: false
      t.string :email, null: false
      t.string :name, null: false
      t.string :avatar_url
      t.text :youtube_access_token # Use text for potentially long tokens
      t.text :youtube_refresh_token
      t.datetime :youtube_token_expires_at
      t.boolean :active, default: true, null: false
      t.boolean :admin, default: false, null: false
      t.datetime :last_sign_in_at

      t.timestamps
    end
    
    # Add indexes for performance and uniqueness
    add_index :users, [:provider, :uid], unique: true
    add_index :users, :email, unique: true
    add_index :users, :active
    add_index :users, :admin
  end
end

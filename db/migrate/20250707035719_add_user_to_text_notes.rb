class AddUserToTextNotes < ActiveRecord::Migration[8.0]
  def up
    # First, add the column without the not null constraint
    add_reference :text_notes, :user, null: true, foreign_key: true
    
    # Create a default admin user if no users exist
    if User.count == 0
      admin_user = User.create!(
        provider: "google_oauth2",
        uid: "admin-default",
        email: "admin@wordsoftruth.app",
        name: "System Admin",
        admin: true,
        active: true
      )
      
      # Assign all existing text notes to this admin user
      TextNote.where(user_id: nil).update_all(user_id: admin_user.id)
    else
      # Assign orphaned text notes to the first admin user, or first user if no admin exists
      default_user = User.admin.first || User.first
      TextNote.where(user_id: nil).update_all(user_id: default_user.id) if default_user
    end
    
    # Now make the column not null
    change_column_null :text_notes, :user_id, false
  end
  
  def down
    remove_reference :text_notes, :user, foreign_key: true
  end
end

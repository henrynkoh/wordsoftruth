class AddPerformanceIndexesToTextNotes < ActiveRecord::Migration[8.0]
  def change
    # Composite indexes for common query patterns
    add_index :text_notes, [:user_id, :created_at], name: 'index_text_notes_on_user_and_created_at' unless index_exists?(:text_notes, [:user_id, :created_at])
    add_index :text_notes, [:user_id, :status], name: 'index_text_notes_on_user_and_status' unless index_exists?(:text_notes, [:user_id, :status])
    add_index :text_notes, [:user_id, :theme], name: 'index_text_notes_on_user_and_theme' unless index_exists?(:text_notes, [:user_id, :theme])
    add_index :text_notes, [:status, :created_at], name: 'index_text_notes_on_status_and_created_at' unless index_exists?(:text_notes, [:status, :created_at])
    
    # Individual performance indexes
    add_index :text_notes, :theme unless index_exists?(:text_notes, :theme)
    add_index :text_notes, :note_type unless index_exists?(:text_notes, :note_type)
    add_index :text_notes, :video_file_path unless index_exists?(:text_notes, :video_file_path)
    add_index :text_notes, :youtube_video_id unless index_exists?(:text_notes, :youtube_video_id)
    
    # Full-text search preparation (if needed later)
    add_index :text_notes, :title unless index_exists?(:text_notes, :title)
    
    # Performance index for dashboard queries
    add_index :text_notes, [:user_id, :status, :created_at], name: 'index_text_notes_dashboard' unless index_exists?(:text_notes, [:user_id, :status, :created_at])
  end
end

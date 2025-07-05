class CreateTextNotes < ActiveRecord::Migration[8.0]
  def change
    create_table :text_notes do |t|
      t.string :title, limit: 100
      t.text :content, null: false
      t.text :enhanced_content
      t.integer :theme, default: 0, null: false
      t.integer :status, default: 0, null: false
      t.integer :note_type, default: 0, null: false
      t.string :video_file_path
      t.string :youtube_video_id
      t.string :youtube_url
      t.float :estimated_duration
      t.integer :korean_character_count, default: 0
      t.json :processing_metadata
      t.timestamps
    end
    
    add_index :text_notes, :theme
    add_index :text_notes, :status
    add_index :text_notes, :note_type
    add_index :text_notes, :created_at
    add_index :text_notes, :youtube_video_id
  end
end
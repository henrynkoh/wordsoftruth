class CreateVideos < ActiveRecord::Migration[8.0]
  def change
    create_table :videos do |t|
      t.references :sermon, null: false, foreign_key: true
      t.text :script
      t.string :video_path
      t.string :thumbnail_path
      t.string :youtube_id
      t.string :status

      t.timestamps
    end
  end
end

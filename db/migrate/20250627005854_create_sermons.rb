class CreateSermons < ActiveRecord::Migration[8.0]
  def change
    create_table :sermons do |t|
      t.string :title
      t.text :scripture
      t.text :interpretation
      t.text :action_points
      t.string :denomination
      t.string :church
      t.string :pastor
      t.datetime :sermon_date
      t.integer :audience_count
      t.string :source_url

      t.timestamps
    end
  end
end

# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_06_28_161500) do
  create_table "audit_logs", force: :cascade do |t|
    t.string "auditable_type"
    t.integer "auditable_id"
    t.string "action"
    t.text "audit_data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "business_activity_logs", force: :cascade do |t|
    t.string "activity_type", null: false
    t.string "entity_type"
    t.integer "entity_id"
    t.string "user_id"
    t.string "operation_name"
    t.string "metric_name"
    t.decimal "metric_value", precision: 15, scale: 4
    t.text "context"
    t.datetime "performed_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["activity_type", "performed_at"], name: "index_business_activity_logs_on_type_and_time"
    t.index ["activity_type"], name: "index_business_activity_logs_on_activity_type"
    t.index ["entity_id"], name: "index_business_activity_logs_on_entity_id"
    t.index ["entity_type", "entity_id"], name: "index_business_activity_logs_on_entity"
    t.index ["entity_type"], name: "index_business_activity_logs_on_entity_type"
    t.index ["performed_at", "activity_type"], name: "index_business_activity_logs_on_time_and_type"
    t.index ["performed_at"], name: "index_business_activity_logs_on_performed_at"
    t.index ["user_id", "performed_at"], name: "index_business_activity_logs_on_user_and_time"
    t.index ["user_id"], name: "index_business_activity_logs_on_user_id"
  end

  create_table "sermons", force: :cascade do |t|
    t.string "title"
    t.text "scripture"
    t.text "interpretation"
    t.text "action_points"
    t.string "denomination"
    t.string "church"
    t.string "pastor"
    t.datetime "sermon_date"
    t.integer "audience_count"
    t.string "source_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["church"], name: "index_sermons_on_church"
    t.index ["created_at", "id"], name: "index_sermons_on_created_at_and_id"
    t.index ["created_at"], name: "index_sermons_on_created_at"
    t.index ["denomination"], name: "index_sermons_on_denomination"
    t.index ["pastor"], name: "index_sermons_on_pastor"
    t.index ["scripture"], name: "index_sermons_on_scripture"
    t.index ["title"], name: "index_sermons_on_title"
  end

  create_table "text_notes", force: :cascade do |t|
    t.string "title", limit: 100
    t.text "content", null: false
    t.text "enhanced_content"
    t.integer "theme", default: 0, null: false
    t.integer "status", default: 0, null: false
    t.integer "note_type", default: 0, null: false
    t.string "video_file_path"
    t.string "youtube_video_id"
    t.string "youtube_url"
    t.float "estimated_duration"
    t.integer "korean_character_count", default: 0
    t.json "processing_metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_text_notes_on_created_at"
    t.index ["note_type"], name: "index_text_notes_on_note_type"
    t.index ["status"], name: "index_text_notes_on_status"
    t.index ["theme"], name: "index_text_notes_on_theme"
    t.index ["youtube_video_id"], name: "index_text_notes_on_youtube_video_id"
  end

  create_table "videos", force: :cascade do |t|
    t.integer "sermon_id", null: false
    t.text "script"
    t.string "video_path"
    t.string "thumbnail_path"
    t.string "youtube_id"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_videos_on_created_at"
    t.index ["sermon_id", "status"], name: "index_videos_on_sermon_id_and_status"
    t.index ["sermon_id"], name: "index_videos_on_sermon_id"
    t.index ["status", "created_at"], name: "index_videos_on_status_and_created_at"
    t.index ["status"], name: "index_videos_on_status"
    t.index ["youtube_id"], name: "index_videos_on_youtube_id"
  end

  add_foreign_key "videos", "sermons"
end

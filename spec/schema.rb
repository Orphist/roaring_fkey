# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

version = 1

return if ActiveRecord::Migrator.current_version == version
ActiveRecord::Schema.define(version: version) do
  self.verbose = false

  enable_extension "plpgsql"
  enable_extension "roaringbitmap"

  create_table "items", force: :cascade do |t|
    t.string   "name"
    t.bigint   "tag_ids", array: true, default: "{1}"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "tags", force: :cascade do |t|
    t.string "name"
    t.roaringbitmap "comment_ids"
  end

  create_table "videos", force: :cascade do |t|
    t.roaringbitmap   "tag_ids"
    t.string   "title"
    t.string   "url"
    t.integer   "type"
    # t.enum     "conflicts", enum_type: :conflicts, array: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "comments", force: :cascade do |t|
    t.string   "title"
  end

  create_table "authors", force: :cascade do |t|
    t.string   "name"
    t.string   "type"
    t.integer     "specialty"#, enum_type: :specialties
  end

  create_table "activities", force: :cascade do |t|
    t.integer  "author_id"
    t.string   "title"
    t.boolean  "active"
    t.integer     "kind"#,                    enum_type: :types
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "posts", force: :cascade do |t|
    t.integer  "author_id"
    t.integer  "activity_id"
    t.string   "title"
    t.text     "content"
    t.integer     "status"#,    enum_type: :content_status
    t.index ["author_id"], name: "index_posts_on_author_id", using: :btree
  end
end

ActiveRecord::Base.connection.schema_cache.clear!

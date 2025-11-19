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

version = 12

return if ActiveRecord::Migrator.current_version == version
ActiveRecord::Schema.define(version: version) do
  self.verbose = true

  enable_extension "plpgsql"
  enable_extension "roaringbitmap"

  create_table "items", force: :cascade do |t|
    t.string   "name"
    t.bigint   "tag_ids", array: true, default: []
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "tags", id: :bigint, force: :cascade do |t|
    t.string "name"
    t.roaringbitmap "comment_ids", default: "'{}'::roaringbitmap"
  end

  create_table "videos", force: :cascade do |t|
    t.roaringbitmap64 "tag_ids", default: "'{}'::roaringbitmap64"
    t.string   "title"
    t.string   "url"
    t.integer   "type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "comments", id: :int, force: :cascade do |t|
    t.string   "title"
  end

  create_table "authors", force: :cascade do |t|
    t.string   "name"
    t.string   "type"
    t.integer  "specialty"
  end

  create_table "activities", force: :cascade do |t|
    t.integer  "author_id"
    t.string   "title"
    t.boolean  "active"
    t.integer  "kind"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "posts", force: :cascade do |t|
    t.integer  "author_id"
    t.integer  "activity_id"
    t.string   "title"
    t.text     "content"
    t.integer  "status"
    t.index ["author_id"], name: "index_posts_on_author_id", using: :btree
  end
end

ActiveRecord::Base.connection.schema_cache.clear!

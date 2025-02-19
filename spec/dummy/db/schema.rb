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

ActiveRecord::Schema.define(version: 1) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"
  enable_extension "roaringbitmap"

  create_table "activities", force: :cascade do |t|
    t.integer "author_id"
    t.string "title"
    t.boolean "active"
    t.integer "kind"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "authors", force: :cascade do |t|
    t.string "name"
    t.string "type"
    t.integer "specialty"
  end

  create_table "comments", force: :cascade do |t|
    t.string "title"
  end

  create_table "items", force: :cascade do |t|
    t.string "name"
    t.bigint "tag_ids", default: [1], array: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "posts", force: :cascade do |t|
    t.integer "author_id"
    t.integer "activity_id"
    t.string "title"
    t.text "content"
    t.integer "status"
    t.index ["author_id"], name: "index_posts_on_author_id"
  end

  create_table "tags", force: :cascade do |t|
    t.string "name"
    t.roaringbitmap "comment_ids"
  end

  create_table "videos", force: :cascade do |t|
    t.roaringbitmap "tag_ids"
    t.string "title"
    t.string "url"
    t.integer "type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

end

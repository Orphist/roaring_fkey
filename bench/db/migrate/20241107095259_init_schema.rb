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

class InitSchema < ActiveRecord::Migration[6.1]

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"
  enable_extension "roaringbitmap"

  create_table :authors do |t|
    t.string :first_name
    t.string :last_name
    t.string :title

    t.timestamps
  end

  create_table :suppliers do |t|
    t.string :name

    t.timestamps
  end

  create_table :books do |t|
    t.string :title
    t.string :isbn

    t.integer :views
    t.integer :year_published
    t.boolean :out_of_print

    t.references :author, foreign_key: true
    t.references :supplier, foreign_key: true

    t.timestamps
  end

  create_table :customers do |t|
    t.string :name
    t.integer :visits
    t.integer :orders_count

    t.timestamps
  end

  create_table :orders do |t|
    t.integer :status
    t.integer :total

    t.references :customer, foreign_key: true

    t.timestamps
    t.index ["total"], name: "index_orders_on_total"
  end

  create_table :reviews do |t|
    t.string :title
    t.string :body

    t.integer :rating
    t.integer :state

    t.references :book, foreign_key: true
    t.references :customer, foreign_key: true

    t.timestamps
    t.index ["rating"], name: "index_reviews_on_rating"
  end

  create_table :books_orders, id: false do |t|
    t.references :book, foreign_key: true
    t.references :order, foreign_key: true
  end
  
### roaring_fkey part of schema:

  create_table :roaring_fkey_authors do |t|
    t.string :first_name
    t.string :last_name
    t.string :title

    t.roaringbitmap :book_ids

    t.timestamps
  end

  create_table :roaring_fkey_suppliers do |t|
    t.string :name

    t.roaringbitmap :book_ids

    t.timestamps
  end

  create_table :roaring_fkey_books do |t|
    t.string :title
    t.string :isbn

    t.integer :views
    t.integer :year_published
    t.boolean :out_of_print

    t.roaringbitmap :review_ids
    t.roaringbitmap :order_ids

    t.timestamps
  end

  create_table :roaring_fkey_customers do |t|
    t.string :name
    t.integer :visits

    t.roaringbitmap :review_ids
    t.roaringbitmap :order_ids

    t.timestamps
  end

  create_table :roaring_fkey_orders do |t|
    t.integer :status
    t.integer :total

    t.roaringbitmap :book_ids

    t.references :roaring_fkey_customer, foreign_key: true

    t.timestamps
    t.index ["total"], name: "index_roaring_fkey_orders_on_total"
  end

  create_table :roaring_fkey_reviews do |t|
    t.string :title
    t.string :body

    t.integer :rating
    t.integer :state

    t.references :roaring_fkey_book, foreign_key: true
    t.references :roaring_fkey_customer, foreign_key: true

    t.timestamps
    t.index ["rating"], name: "index_roaring_fkey_reviews_on_rating"
  end
end
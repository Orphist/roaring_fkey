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

ActiveRecord::Schema.define(version: 2025_11_25_081419) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"
  enable_extension "roaringbitmap"

  create_table "authors", force: :cascade do |t|
    t.string "first_name"
    t.string "last_name"
    t.string "title"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "books", force: :cascade do |t|
    t.string "title"
    t.string "isbn"
    t.integer "views"
    t.integer "year_published"
    t.boolean "out_of_print"
    t.bigint "author_id"
    t.bigint "supplier_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["author_id"], name: "index_books_on_author_id"
    t.index ["supplier_id"], name: "index_books_on_supplier_id"
  end

  create_table "books_orders", id: false, force: :cascade do |t|
    t.bigint "book_id"
    t.bigint "order_id"
    t.index ["book_id"], name: "index_books_orders_on_book_id"
    t.index ["order_id"], name: "index_books_orders_on_order_id"
  end

  create_table "customers", force: :cascade do |t|
    t.string "name"
    t.integer "visits"
    t.integer "orders_count"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "orders", force: :cascade do |t|
    t.integer "status"
    t.integer "total"
    t.bigint "customer_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["customer_id"], name: "index_orders_on_customer_id"
    t.index ["total"], name: "index_orders_on_total"
  end

  create_table "reviews", force: :cascade do |t|
    t.string "title"
    t.string "body"
    t.integer "rating"
    t.integer "state"
    t.bigint "book_id"
    t.bigint "customer_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["book_id"], name: "index_reviews_on_book_id"
    t.index ["customer_id"], name: "index_reviews_on_customer_id"
    t.index ["rating"], name: "index_reviews_on_rating"
  end

  create_table "roaring_fkey_authors", force: :cascade do |t|
    t.string "first_name"
    t.string "last_name"
    t.string "title"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.roaringbitmap64 "book_ids"
  end

  create_table "roaring_fkey_books", force: :cascade do |t|
    t.string "title"
    t.string "isbn"
    t.integer "views"
    t.integer "year_published"
    t.boolean "out_of_print"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.roaringbitmap64 "review_ids"
    t.roaringbitmap64 "order_ids"
  end

  create_table "roaring_fkey_customers", force: :cascade do |t|
    t.string "name"
    t.integer "visits"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.roaringbitmap64 "review_ids"
    t.roaringbitmap64 "order_ids"
  end

  create_table "roaring_fkey_orders", force: :cascade do |t|
    t.integer "status"
    t.integer "total"
    t.bigint "roaring_fkey_customer_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.roaringbitmap64 "book_ids"
    t.index ["roaring_fkey_customer_id"], name: "index_roaring_fkey_orders_on_roaring_fkey_customer_id"
    t.index ["total"], name: "index_roaring_fkey_orders_on_total"
  end

  create_table "roaring_fkey_reviews", force: :cascade do |t|
    t.string "title"
    t.string "body"
    t.integer "rating"
    t.integer "state"
    t.bigint "roaring_fkey_book_id"
    t.bigint "roaring_fkey_customer_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["rating"], name: "index_roaring_fkey_reviews_on_rating"
    t.index ["roaring_fkey_book_id"], name: "index_roaring_fkey_reviews_on_roaring_fkey_book_id"
    t.index ["roaring_fkey_customer_id"], name: "index_roaring_fkey_reviews_on_roaring_fkey_customer_id"
  end

  create_table "roaring_fkey_suppliers", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.roaringbitmap64 "book_ids"
  end

  create_table "suppliers", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "tpc_h_rfkey_customer", primary_key: "c_custkey", force: :cascade do |t|
    t.string "c_name", limit: 25
    t.string "c_address", limit: 40
    t.string "c_phone", limit: 15
    t.decimal "c_acctbal"
    t.string "c_mktsegment", limit: 10
    t.string "c_comment", limit: 117
    t.roaringbitmap64 "o_orderkey_ids"
  end

  create_table "tpc_h_rfkey_lineitem", primary_key: ["l_orderkey", "l_linenumber"], force: :cascade do |t|
    t.bigint "l_orderkey", null: false
    t.integer "l_linenumber", null: false
    t.bigint "l_partkey", null: false
    t.bigint "l_suppkey", null: false
    t.decimal "l_quantity"
    t.decimal "l_extendedprice"
    t.decimal "l_discount"
    t.decimal "l_tax"
    t.string "l_returnflag", limit: 1
    t.string "l_linestatus", limit: 1
    t.date "l_shipdate"
    t.date "l_commitdate"
    t.date "l_receiptdate"
    t.string "l_shipinstruct", limit: 25
    t.string "l_shipmode", limit: 10
    t.string "l_comment", limit: 44
  end

  create_table "tpc_h_rfkey_nation", primary_key: "n_nationkey", force: :cascade do |t|
    t.string "n_name", limit: 25
    t.string "n_comment", limit: 152
    t.roaringbitmap64 "s_suppkey_ids"
    t.roaringbitmap64 "c_custkey_ids"
  end

  create_table "tpc_h_rfkey_orders", primary_key: "o_orderkey", force: :cascade do |t|
    t.string "o_orderstatus", limit: 1
    t.decimal "o_totalprice"
    t.date "o_orderdate"
    t.string "o_orderpriority", limit: 15
    t.string "o_clerk", limit: 15
    t.integer "o_shippriority"
    t.string "o_comment", limit: 79
    t.roaringbitmap64 "l_orderkey_ids"
    t.roaringbitmap64 "l_linenumber_ids"
    t.roaringbitmap64 "l_partkey_ids"
    t.roaringbitmap64 "l_suppkey_ids"
  end

  create_table "tpc_h_rfkey_part", primary_key: "p_partkey", force: :cascade do |t|
    t.string "p_name", limit: 55
    t.string "p_mfgr", limit: 25
    t.string "p_brand", limit: 10
    t.string "p_type", limit: 25
    t.integer "p_size"
    t.string "p_container", limit: 10
    t.decimal "p_retailprice"
    t.string "p_comment", limit: 23
    t.roaringbitmap64 "ps_partkey_suppkey_ids"
  end

  create_table "tpc_h_rfkey_partsupp", primary_key: ["ps_partkey", "ps_suppkey"], force: :cascade do |t|
    t.integer "ps_partkey", null: false
    t.integer "ps_suppkey", null: false
    t.integer "ps_availqty"
    t.decimal "ps_supplycost"
    t.string "ps_comment", limit: 199
    t.roaringbitmap64 "l_orderkey_linenumber_ids"
  end

  create_table "tpc_h_rfkey_region", primary_key: "r_regionkey", force: :cascade do |t|
    t.string "r_name", limit: 25
    t.string "r_comment", limit: 152
    t.roaringbitmap64 "n_nationkey_ids"
  end

  create_table "tpc_h_rfkey_supplier", primary_key: "s_suppkey", force: :cascade do |t|
    t.string "s_name", limit: 25
    t.string "s_address", limit: 40
    t.string "s_phone", limit: 15
    t.decimal "s_acctbal"
    t.string "s_comment", limit: 101
    t.roaringbitmap64 "ps_partkey_suppkey_ids"
  end

  create_table "tpc_hcustomer", primary_key: "c_custkey", force: :cascade do |t|
    t.string "c_name", limit: 25
    t.string "c_address", limit: 40
    t.bigint "c_nationkey", null: false
    t.string "c_phone", limit: 15
    t.decimal "c_acctbal"
    t.string "c_mktsegment", limit: 10
    t.string "c_comment", limit: 117
  end

  create_table "tpc_hlineitem", primary_key: ["l_orderkey", "l_linenumber"], force: :cascade do |t|
    t.bigint "l_orderkey", null: false
    t.bigint "l_partkey", null: false
    t.bigint "l_suppkey", null: false
    t.integer "l_linenumber", null: false
    t.decimal "l_quantity"
    t.decimal "l_extendedprice"
    t.decimal "l_discount"
    t.decimal "l_tax"
    t.string "l_returnflag", limit: 1
    t.string "l_linestatus", limit: 1
    t.date "l_shipdate"
    t.date "l_commitdate"
    t.date "l_receiptdate"
    t.string "l_shipinstruct", limit: 25
    t.string "l_shipmode", limit: 10
    t.string "l_comment", limit: 44
  end

  create_table "tpc_hnation", primary_key: "n_nationkey", force: :cascade do |t|
    t.string "n_name", limit: 25
    t.bigint "n_regionkey", null: false
    t.string "n_comment", limit: 152
  end

  create_table "tpc_horders", primary_key: "o_orderkey", force: :cascade do |t|
    t.bigint "o_custkey", null: false
    t.string "o_orderstatus", limit: 1
    t.decimal "o_totalprice"
    t.date "o_orderdate"
    t.string "o_orderpriority", limit: 15
    t.string "o_clerk", limit: 15
    t.integer "o_shippriority"
    t.string "o_comment", limit: 79
  end

  create_table "tpc_hpart", primary_key: "p_partkey", force: :cascade do |t|
    t.string "p_name", limit: 55
    t.string "p_mfgr", limit: 25
    t.string "p_brand", limit: 10
    t.string "p_type", limit: 25
    t.integer "p_size"
    t.string "p_container", limit: 10
    t.decimal "p_retailprice"
    t.string "p_comment", limit: 23
  end

  create_table "tpc_hpartsupp", primary_key: ["ps_partkey", "ps_suppkey"], force: :cascade do |t|
    t.bigint "ps_partkey", null: false
    t.bigint "ps_suppkey", null: false
    t.integer "ps_availqty"
    t.decimal "ps_supplycost"
    t.string "ps_comment", limit: 199
  end

  create_table "tpc_hregion", primary_key: "r_regionkey", force: :cascade do |t|
    t.string "r_name", limit: 25
    t.string "r_comment", limit: 152
  end

  create_table "tpc_hsupplier", primary_key: "s_suppkey", force: :cascade do |t|
    t.string "s_name", limit: 25
    t.string "s_address", limit: 40
    t.bigint "s_nationkey", null: false
    t.string "s_phone", limit: 15
    t.decimal "s_acctbal"
    t.string "s_comment", limit: 101
  end

  add_foreign_key "books", "authors"
  add_foreign_key "books", "suppliers"
  add_foreign_key "books_orders", "books"
  add_foreign_key "books_orders", "orders"
  add_foreign_key "orders", "customers"
  add_foreign_key "reviews", "books"
  add_foreign_key "reviews", "customers"
  add_foreign_key "roaring_fkey_orders", "roaring_fkey_customers"
  add_foreign_key "roaring_fkey_reviews", "roaring_fkey_books"
  add_foreign_key "roaring_fkey_reviews", "roaring_fkey_customers"
  add_foreign_key "tpc_hcustomer", "tpc_hnation", column: "c_nationkey", primary_key: "n_nationkey"
  add_foreign_key "tpc_hlineitem", "tpc_horders", column: "l_orderkey", primary_key: "o_orderkey"
  add_foreign_key "tpc_hlineitem", "tpc_hpartsupp", column: "l_partkey", primary_key: "ps_partkey", name: "fk_lineitem_partsupp"
  add_foreign_key "tpc_hnation", "tpc_hregion", column: "n_regionkey", primary_key: "r_regionkey"
  add_foreign_key "tpc_horders", "tpc_hcustomer", column: "o_custkey", primary_key: "c_custkey"
  add_foreign_key "tpc_hpartsupp", "tpc_hpart", column: "ps_partkey", primary_key: "p_partkey"
  add_foreign_key "tpc_hpartsupp", "tpc_hsupplier", column: "ps_suppkey", primary_key: "s_suppkey"
  add_foreign_key "tpc_hsupplier", "tpc_hnation", column: "s_nationkey", primary_key: "n_nationkey"
end

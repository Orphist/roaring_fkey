class InitSchemaTpcHBitmap < ActiveRecord::Migration[6.1]
  def change
    create_table :tpc_h_rfkey_part, primary_key: :p_partkey do |t|
      t.string :p_name, limit: 55
      t.string :p_mfgr, limit: 25
      t.string :p_brand, limit: 10
      t.string :p_type, limit: 25
      t.integer :p_size
      t.string :p_container, limit: 10
      t.decimal :p_retailprice
      t.string :p_comment, limit: 23

      # Bitmap for inverse relationship: part has many partsupp
      t.roaringbitmap64 :ps_partkey_suppkey_ids
    end

    create_table :tpc_h_rfkey_region, primary_key: :r_regionkey do |t|
      t.string :r_name, limit: 25
      t.string :r_comment, limit: 152

      # Bitmap for inverse relationship: region has many nations
      t.roaringbitmap64 :n_nationkey_ids
    end

    create_table :tpc_h_rfkey_nation, primary_key: :n_nationkey do |t|
      t.string :n_name, limit: 25
      t.string :n_comment, limit: 152

      # Bitmap for inverse relationships
      t.roaringbitmap64 :s_suppkey_ids     # nation has many suppliers
      t.roaringbitmap64 :c_custkey_ids     # nation has many customers
    end

    create_table :tpc_h_rfkey_supplier, primary_key: :s_suppkey do |t|
      t.string :s_name, limit: 25
      t.string :s_address, limit: 40
      t.string :s_phone, limit: 15
      t.decimal :s_acctbal
      t.string :s_comment, limit: 101

      # Bitmap for inverse relationship: supplier has many partsupp
      t.roaringbitmap64 :ps_partkey_suppkey_ids
    end

    create_table :tpc_h_rfkey_customer, primary_key: :c_custkey do |t|
      t.string :c_name, limit: 25
      t.string :c_address, limit: 40
      t.string :c_phone, limit: 15
      t.decimal :c_acctbal
      t.string :c_mktsegment, limit: 10
      t.string :c_comment, limit: 117

      # Bitmap for inverse relationship: customer has many orders
      t.roaringbitmap64 :o_orderkey_ids
    end

    create_table :tpc_h_rfkey_partsupp, primary_key: [:ps_partkey, :ps_suppkey] do |t|
      t.integer :ps_partkey
      t.integer :ps_suppkey
      t.integer :ps_availqty
      t.decimal :ps_supplycost
      t.string :ps_comment, limit: 199

      # Bitmap for inverse relationship: partsupp has many lineitems
      t.roaringbitmap64 :l_orderkey_linenumber_ids
    end

    create_table :tpc_h_rfkey_orders, primary_key: :o_orderkey do |t|
      t.string :o_orderstatus, limit: 1
      t.decimal :o_totalprice
      t.date :o_orderdate
      t.string :o_orderpriority, limit: 15
      t.string :o_clerk, limit: 15
      t.integer :o_shippriority
      t.string :o_comment, limit: 79

      # Bitmap for inverse relationship: order has many lineitems
      t.roaringbitmap64 :l_orderkey_ids
      t.roaringbitmap64 :l_linenumber_ids
      t.roaringbitmap64 :l_partkey_ids
      t.roaringbitmap64 :l_suppkey_ids
    end

    create_table :tpc_h_rfkey_lineitem, primary_key: [:l_orderkey, :l_linenumber] do |t|
      t.bigint :l_orderkey, null: false
      t.integer :l_linenumber, null: false

      t.bigint :l_partkey, null: false
      t.bigint :l_suppkey, null: false

      t.decimal :l_quantity
      t.decimal :l_extendedprice
      t.decimal :l_discount
      t.decimal :l_tax
      t.string :l_returnflag, limit: 1
      t.string :l_linestatus, limit: 1
      t.date :l_shipdate
      t.date :l_commitdate
      t.date :l_receiptdate
      t.string :l_shipinstruct, limit: 25
      t.string :l_shipmode, limit: 10
      t.string :l_comment, limit: 44
    end
  end
end

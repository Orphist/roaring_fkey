class InitSchemaTpcH < ActiveRecord::Migration[6.1]
  def change
    create_table :tpc_hpart, primary_key: :p_partkey do |t|
      t.string :p_name, limit: 55
      t.string :p_mfgr, limit: 25
      t.string :p_brand, limit: 10
      t.string :p_type, limit: 25
      t.integer :p_size
      t.string :p_container, limit: 10
      t.decimal :p_retailprice
      t.string :p_comment, limit: 23
    end

    create_table :tpc_hregion, primary_key: :r_regionkey do |t|
      t.string :r_name, limit: 25
      t.string :r_comment, limit: 152
    end

    create_table :tpc_hnation, primary_key: :n_nationkey do |t|
      t.string :n_name, limit: 25
      t.bigint :n_regionkey, null: false
      t.string :n_comment, limit: 152
    end

    create_table :tpc_hsupplier, primary_key: :s_suppkey do |t|
      t.string :s_name, limit: 25
      t.string :s_address, limit: 40
      t.bigint :s_nationkey, null: false
      t.string :s_phone, limit: 15
      t.decimal :s_acctbal
      t.string :s_comment, limit: 101
    end

    create_table :tpc_hcustomer, primary_key: :c_custkey do |t|
      t.string :c_name, limit: 25
      t.string :c_address, limit: 40
      t.bigint :c_nationkey, null: false
      t.string :c_phone, limit: 15
      t.decimal :c_acctbal
      t.string :c_mktsegment, limit: 10
      t.string :c_comment, limit: 117
    end

    create_table :tpc_hpartsupp, primary_key: [:ps_partkey, :ps_suppkey] do |t|
      t.bigint :ps_partkey, null: false
      t.bigint :ps_suppkey, null: false
      t.integer :ps_availqty
      t.decimal :ps_supplycost
      t.string :ps_comment, limit: 199
    end

    create_table :tpc_horders, primary_key: :o_orderkey do |t|
      t.bigint :o_custkey, null: false
      t.string :o_orderstatus, limit: 1
      t.decimal :o_totalprice
      t.date :o_orderdate
      t.string :o_orderpriority, limit: 15
      t.string :o_clerk, limit: 15
      t.integer :o_shippriority
      t.string :o_comment, limit: 79
    end

    create_table :tpc_hlineitem, primary_key: [:l_orderkey, :l_linenumber] do |t|
      t.bigint :l_orderkey, null: false
      t.bigint :l_partkey, null: false
      t.bigint :l_suppkey, null: false
      t.integer :l_linenumber
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

    add_foreign_key :tpc_hsupplier, :tpc_hnation, column: :s_nationkey, primary_key: :n_nationkey
    add_foreign_key :tpc_hnation, :tpc_hregion, column: :n_regionkey, primary_key: :r_regionkey
    add_foreign_key :tpc_hcustomer, :tpc_hnation, column: :c_nationkey, primary_key: :n_nationkey
    add_foreign_key :tpc_horders, :tpc_hcustomer, column: :o_custkey, primary_key: :c_custkey

    add_foreign_key :tpc_hpartsupp, :tpc_hpart, column: :ps_partkey, primary_key: :p_partkey
    add_foreign_key :tpc_hpartsupp, :tpc_hsupplier, column: :ps_suppkey, primary_key: :s_suppkey

    add_foreign_key :tpc_hlineitem, :tpc_horders, column: :l_orderkey, primary_key: :o_orderkey

    # Note: since Rails doesn't support composite foreign keys directly, so add them with execute
    execute <<-SQL
      ALTER TABLE tpc_hlineitem
      ADD CONSTRAINT fk_lineitem_partsupp
      FOREIGN KEY (l_partkey, l_suppkey)
      REFERENCES tpc_hpartsupp(ps_partkey, ps_suppkey);
    SQL
  end
end
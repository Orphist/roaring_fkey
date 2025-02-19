# frozen_string_literal: true

require "benchmark/ips"
require_relative "../config/environment"

Benchmarker.connect!
Benchmarker.db_data_report

$stdout.puts "\\/\\/\\/\\/\\/\\/Count orders for random customer:"
$stdout.puts "RoaringFkey with reference roaring_fkey_customer_id"
ar_rel = Customer.includes("orders").where(id: Customer.random.id, orders: { status: 'shipped' })
# default join via _ids @> id, so add ON condition explicitly
rb_rel = RoaringFkey::Customer.includes(:orders).
        where("roaring_fkey_customers.id = roaring_fkey_customer_id").
        where(id: Customer.random.id, orders: { status: 'shipped' })
Benchmarker.bench_stage(ar_rel, rb_rel)

$stdout.puts "RoaringFkey table join with default condition"
ar_rel = Customer.includes("orders").where(id: Customer.random.id, orders: { status: 'shipped' })
# default join via _ids @> id
rb_rel = RoaringFkey::Customer.includes(:orders).
        where(id: Customer.random.id, orders: { status: 'shipped' })
Benchmarker.bench_stage(ar_rel, rb_rel)


$stdout.puts "list of books from 20 random orders:"
orders_qty = 20

ar_rel = Book.includes(:orders).
        where(orders: { id: Order.random_ids(orders_qty) }).select(:id)
# default join via _ids @> id
rb_rel = RoaringFkey::Book.includes(:orders).
        where(orders: { id: RoaringFkey::Order.random_ids(orders_qty) }).select(:id)
Benchmarker.bench_stage(ar_rel, rb_rel)

# frozen_string_literal: true

require "benchmark/ips"
require_relative "../config/environment"

Benchmarker.connect!
Benchmarker.db_data_report

top_k_scale = 20

$stdout.puts "top_k_scale = #{top_k_scale} benchmark run..."

$stdout.puts "\\/\\/\\/\\/\\/\\/ top k orders by books qty:"
ar_rel = BookOrder.
          select("count(book_id) book_qty, order_id").
          group(:order_id).
          order("count(book_id) desc").
          limit(top_k_scale)
rb_rel = RoaringFkey::Order.
          select("rb_cardinality(book_ids) book_qty, id").
          order("rb_cardinality(book_ids) desc").
          limit(top_k_scale)
Benchmarker.bench_stage(ar_rel, rb_rel)


$stdout.puts "\\/\\/\\/\\/\\/\\/ top k books most ordered:"
ar_rel = BookOrder.
      select("count(order_id) order_qty, book_id").
      group(:book_id).
      order("count(order_id) desc").
      limit(top_k_scale)
rb_rel = RoaringFkey::Book.
      select("rb_cardinality(order_ids) book_qty, id book_id").
      order("rb_cardinality(order_ids) desc").
      limit(top_k_scale)
Benchmarker.bench_stage(ar_rel, rb_rel)

$stdout.puts "\\/\\/\\/\\/\\/\\/ top k books most reviewed:"
ar_rel = Review.
      select("count(book_id) book_review_qty, book_id").
      group(:book_id).
      order("count(book_id) desc").
      limit(top_k_scale)
rb_rel = RoaringFkey::Book.
      select("rb_cardinality(review_ids) book_review_qty, id").
      order("rb_cardinality(review_ids) desc").
      limit(top_k_scale)
Benchmarker.bench_stage(ar_rel, rb_rel)


$stdout.puts "\\/\\/\\/\\/\\/\\/ top k books [most reviewed && most rated] in reviews:"
ar_rel = Review.
      select("count(book_id) book_review_qty, avg(rating) book_average_rating, book_id").
      group(:book_id).
      order("count(book_id) desc, avg(rating) desc").
      limit(top_k_scale)
rb_rel = RoaringFkey::Review.
      joins("INNER JOIN roaring_fkey_books ON roaring_fkey_book_id = roaring_fkey_books.id").
      select("count(roaring_fkey_book_id) book_review_qty, avg(rating) book_average_rating, roaring_fkey_book_id").
      group(:roaring_fkey_book_id).
      order("count(roaring_fkey_book_id) desc, avg(rating) desc").
      limit(top_k_scale)
rb_rel = RoaringFkey::Book.
      joins("INNER JOIN roaring_fkey_reviews ON (roaring_fkey_book_id = roaring_fkey_books.id AND NOT (rb_is_empty(review_ids)))").
      select("count(review_ids) book_review_qty, avg(rating) book_average_rating, roaring_fkey_book_id").
      group(:roaring_fkey_book_id).
      order("count(review_ids) desc, avg(rating) desc").
      limit(top_k_scale)
Benchmarker.bench_stage(ar_rel, rb_rel)


$stdout.puts "\\/\\/\\/\\/\\/\\/ top k books [most reviewed]:"
ar_rel = Book.joins(:reviews).
      having("COUNT(distinct reviews.id) > #{top_k_scale}").
      group("books.title").
      select("COUNT(distinct reviews.id) review_qty, books.title")
rb_rel = RoaringFkey::Book.
      having("COUNT(roaring_fkey_books.review_ids) > #{top_k_scale}").
      group("roaring_fkey_books.title").
      select("COUNT(roaring_fkey_books.review_ids) review_qty, roaring_fkey_books.title")
Benchmarker.bench_stage(ar_rel, rb_rel)


$stdout.puts "\\/\\/\\/\\/\\/\\/ top k orders total > 10k :"
ar_rel = Order.
      select("created_at as ordered_date, total as total_price").
      where("total > ?", 10000).
      limit(top_k_scale)
rb_rel = RoaringFkey::Order.
      select("created_at as ordered_date, total as total_price").
      where("total > ?", 10000).
      limit(top_k_scale)
Benchmarker.bench_stage(ar_rel, rb_rel)


$stdout.puts "\\/\\/\\/\\/\\/\\/ top k book most reviewed in top k orders w/total > 10k :"
total_threshold = 1_000_00
ar_rel = Order.joins(books: :reviews).
      select("books.id, count(reviews.id), total").
      where("total > ?", total_threshold).
      group("books.id, total").
      order("count(reviews.id) desc").
      limit(top_k_scale)
# rb_rel = RoaringFkey::Order.
#       joins("INNER JOIN roaring_fkey_books ON roaring_fkey_book_id = roaring_fkey_books.id").
#       select("roaring_fkey_books.id, rb_cardinality(review_ids) reviews_qty, total as total_price").
#       where("total > ?", total_threshold).
#       order("rb_cardinality(review_ids) desc").
#       limit(top_k_scale)

## AR Relation request above - too slow so make request w/raw SQL using rb_or_agg to aggregate unique books.id
stmnt = <<-SQL
  (
    WITH most_reviewed AS(
      SELECT id book_id, rb_cardinality(review_ids) reviews_qty
      FROM roaring_fkey_books
      ORDER BY rb_cardinality(review_ids) DESC
      LIMIT 1000
    )
    SELECT book_id, reviews_qty, total AS total_price
    FROM most_reviewed
    INNER JOIN roaring_fkey_orders ON book_ids @> book_id::INT
    WHERE total > #{total_threshold}
    LIMIT #{top_k_scale}
  ) most_reviewed_books
SQL
rb_rel = RoaringFkey::Book.select('most_reviewed_books.*').from(stmnt)
Benchmarker.bench_stage(ar_rel, rb_rel)

$stdout.puts "\\/\\/\\/\\/\\/\\/ top k customers - reviewers:"
ar_rel = Customer.left_outer_joins(:reviews).
        select("customers.id, COUNT(reviews.id)").
        group("customers.id").
        order("COUNT(reviews.id) desc").
        limit(top_k_scale)

rb_rel = RoaringFkey::Customer.
        select("roaring_fkey_customers.id, rb_cardinality(roaring_fkey_customers.review_ids)").
        order("rb_cardinality(roaring_fkey_customers.review_ids) desc").
        limit(top_k_scale)
Benchmarker.bench_stage(ar_rel, rb_rel)

$stdout.puts "\\/\\/\\/\\/\\/\\/count reviews for books w/rating > 4:"
books_qty = 30

$stdout.puts "for random #{books_qty} books:"
ar_rel = Review.where("rating > 4", book_id: Book.random_ids(books_qty)).limit(top_k_scale).select(:id, :book_id)
rb_rel = RoaringFkey::Review.where("rating > 4", book_id: RoaringFkey::Book.random_ids(books_qty)).limit(top_k_scale).select(:id, :roaring_fkey_book_id)
Benchmarker.bench_stage(ar_rel, rb_rel)

$stdout.puts "for all books:"
ar_rel = Review.where("rating > 4").limit(top_k_scale).select(:id, :book_id)
rb_rel = RoaringFkey::Review.where("rating > 4").limit(top_k_scale).select(:id, :roaring_fkey_book_id)
Benchmarker.bench_stage(ar_rel, rb_rel)

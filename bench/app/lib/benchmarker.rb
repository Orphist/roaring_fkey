# frozen_string_literal: true

require 'dotenv'
require 'tracer'
require "active_support/number_helper"
require "csv"

module Benchmarker
  include ::ActiveSupport::NumberHelper

  module_function

  def connect!
    Dotenv.load
    begin
      config = ActiveRecord::Base.configurations[Rails.env] ||
                  Rails.application.config.database_configuration[Rails.env]
      $stdout.puts "DB config:#{config}"
      ActiveRecord::Base.establish_connection(config)
      connection = ActiveRecord::Base.connection
      connection.execute("SELECT 1")
    rescue ActiveRecord::NoDatabaseError => e
      at_exit do
        puts "-" * 80
        puts "Unable to connect to database.  Please run:"
        puts
        puts "    createdb #{config[:database]}"
        puts "-" * 80
      end
      raise e
    end
  end

  def populate(scale_factor)
    drop_indexes(:books_orders)
    generate_random_funcs
    generate_funcs_ar
    generate_funcs_roaring_fkey

    author_qty = scale_factor * 4
    book_qty = scale_factor * 10
    supplier_qty = scale_factor
    customer_qty = scale_factor * 20
    order_qty = customer_qty * 20
    review_qty = book_qty * 20

    $stdout.puts "Generating #{pretty_count(author_qty)} Author && RoaringFkey::Author records... "
    $stdout.puts "Generating #{pretty_count(customer_qty)} Customer && RoaringFkey::Customer records... "
    $stdout.puts "Generating #{pretty_count(supplier_qty)} Supplier && RoaringFkey::Supplier records... "
    $stdout.puts "Generating #{pretty_count(book_qty)} Book && RoaringFkey::Book records... "
    $stdout.puts "Generating #{pretty_count(order_qty)} Order && RoaringFkey::Order records... "
    $stdout.puts "Generating #{pretty_count(review_qty)} Review && RoaringFkey::Review records... "

    create_ar_records(author_qty, book_qty, supplier_qty, customer_qty, review_qty, order_qty)

    ts = Time.current

    sql_gen_ex('fill_roaring_fkey_authors', author_qty, book_qty)
    sql_gen_ex('fill_roaring_fkey_suppliers', supplier_qty, book_qty)
    sql_gen_ex('fill_roaring_fkey_customers', customer_qty, review_qty, order_qty)

    ts_parallel = Time.current
    threads = [
      Thread.new do
        sql_gen_ex('fill_roaring_fkey_orders', order_qty, book_qty, 1, 4)
      end,
      Thread.new do
        sql_gen_ex('fill_roaring_fkey_orders', order_qty, book_qty, 2, 4)
      end,
      Thread.new do
        sql_gen_ex('fill_roaring_fkey_orders', order_qty, book_qty, 3, 4)
      end,
      Thread.new do
        sql_gen_ex('fill_roaring_fkey_orders', order_qty, book_qty, 4, 4)
      end,
      Thread.new do
        sql_gen_ex('fill_roaring_fkey_books', book_qty, review_qty, order_qty)
      end
    ]
    threads.each(&:join)
    puts "after fill_roaring_fkey_orders:#{Time.current-ts_parallel}s"

    # sql_gen_ex('fill_roaring_fkey_books', book_qty, review_qty, order_qty)

    ts_parallel = Time.current
    # puts "before all:#{ts}"
    threads = [
      Thread.new do
        sql_gen_ex('fill_roaring_fkey_reviews', review_qty, 1, 4)
      end,
      Thread.new do
        sql_gen_ex('fill_roaring_fkey_reviews', review_qty, 2, 4)
      end,
      Thread.new do
        sql_gen_ex('fill_roaring_fkey_reviews', review_qty, 3, 4)
      end,
      Thread.new do
        sql_gen_ex('fill_roaring_fkey_reviews', review_qty, 4, 4)
      end
    ]
    threads.each(&:join)
    puts "after fill_roaring_fkey_reviews:#{Time.current-ts_parallel}s"

    $stdout.puts "⁂#⁂#⁂ Done RoaringFkey - in #{Time.current - ts}s"
  end

  def sql_gen(func, records_qty)
    ts = Time.current

    # ActiveRecord::Base.connection.execute("SELECT #{func}(#{records_qty});")
    ActiveRecord::Base.connection_pool.with_connection do |connection|
      connection.execute "SELECT #{func}(#{records_qty});"
    end
    $stdout.puts "#{(Time.current-ts).round}s #{pretty_count(records_qty)} created #{func}"
  end

  def sql_gen_ex(func, records_qty, extra_qty, extra2_qty = nil, extra3_qty = nil)
    ts = Time.current
    stmnt = "SELECT #{func}(#{records_qty},#{[extra_qty, extra2_qty, extra3_qty].compact.join(',')});"
    # ActiveRecord::Base.connection.execute(stmnt)
    ActiveRecord::Base.connection_pool.with_connection do |connection|
      connection.execute stmnt
    end
    $stdout.puts "#{(Time.current-ts).round}s #{pretty_count(records_qty)} created #{func}"
  end

  def drop_indexes(table_name)
    ActiveRecord::Base.connection_pool.with_connection do |connection|
      stmnt = <<~SQL
        DO $$
        DECLARE
            r record;
        BEGIN
            FOR r IN SELECT
          format('ALTER TABLE "%s" DROP CONSTRAINT %s;',
                 tc.table_name, tc.constraint_name) AS sql_stmnt
        FROM
          information_schema.table_constraints AS tc
          JOIN information_schema.key_column_usage AS kcu
            ON tc.constraint_name = kcu.constraint_name
          JOIN information_schema.constraint_column_usage AS ccu
            ON ccu.constraint_name = tc.constraint_name
        WHERE
          ccu.table_name ilike '#{table_name}'
        or tc.table_name ilike '#{table_name}'
            LOOP                
                EXECUTE r.sql_stmnt;
            END LOOP;
        END$$;
      SQL
      connection.execute stmnt
    end
    ActiveRecord::Base.connection_pool.with_connection do |connection|
      stmnt = <<~SQL
        DO $$
        DECLARE
            r record;
        BEGIN
          FOR r IN SELECT
          format('DROP INDEX %s;', indexname) AS sql_stmnt
         FROM pg_tables t
         LEFT OUTER JOIN pg_class c ON t.tablename=c.relname
         LEFT OUTER JOIN
             ( SELECT c.relname AS ctablename, ipg.relname AS indexname, x.indnatts AS number_of_columns, idx_scan, idx_tup_read, idx_tup_fetch, indexrelname, indisunique FROM pg_index x
                    JOIN pg_class c ON c.oid = x.indrelid
                    JOIN pg_class ipg ON ipg.oid = x.indexrelid
                    JOIN pg_stat_all_indexes psai ON x.indexrelid = psai.indexrelid AND psai.schemaname = 'public' )
             AS foo
             ON t.tablename = foo.ctablename
         WHERE t.schemaname = 'public'
           and  t.tablename = '#{table_name}'
           and indexname is not null
            LOOP              
              EXECUTE r.sql_stmnt;
            END LOOP;
        END$$;
      SQL
      connection.execute stmnt
    end
  end

  def cleanup
    $stdout.puts "Bench running AR cleanup"
    # ActiveRecord::Base.connection_pool.with_connection do |connection|
    #   connection.execute "TRUNCATE TABLE books_orders cascade;"
    # end
    ActiveRecord::Base.connection_pool.with_connection do |connection|
      connection.execute "TRUNCATE TABLE reviews cascade;"
    end
    ActiveRecord::Base.connection_pool.with_connection do |connection|
      connection.execute "TRUNCATE TABLE books cascade;"
    end
    ActiveRecord::Base.connection_pool.with_connection do |connection|
      connection.execute "TRUNCATE TABLE authors cascade;"
    end
    ActiveRecord::Base.connection_pool.with_connection do |connection|
      connection.execute "TRUNCATE TABLE orders cascade;"
    end
    ActiveRecord::Base.connection_pool.with_connection do |connection|
      connection.execute "TRUNCATE TABLE customers cascade;"
    end
    ActiveRecord::Base.connection_pool.with_connection do |connection|
      connection.execute "TRUNCATE TABLE suppliers cascade;"
    end
    $stdout.puts "Bench running RoaringFkey cleanup"
    ActiveRecord::Base.connection.execute("TRUNCATE TABLE roaring_fkey_reviews cascade;")
    ActiveRecord::Base.connection.execute("TRUNCATE TABLE roaring_fkey_authors cascade;")
    ActiveRecord::Base.connection.execute("TRUNCATE TABLE roaring_fkey_customers cascade;")
    ActiveRecord::Base.connection.execute("TRUNCATE TABLE roaring_fkey_books cascade;")
    ActiveRecord::Base.connection.execute("TRUNCATE TABLE roaring_fkey_orders cascade;")
    ActiveRecord::Base.connection.execute("TRUNCATE TABLE roaring_fkey_suppliers cascade;")
  end

  # 40kk orders - 2300sec 410kk rows === 210k row/sec wo/indexes
  def fkey_gen_order_records(book_qty, order_qty, part_num, parts_total = 4)
    ts0 = Time.current
    ts = Time.current

    slice_qty = 70000

    book_id_min, book_id_max = [1, book_qty]
    book_ids = (book_id_min..book_id_max).to_a
    book_order_qty = (1..20).to_a

    order_id_min, order_id_max = get_parts_ids(order_qty, parts_total, part_num)
    slice_counts = ((order_id_max - order_id_min)/slice_qty).to_i+1

    order_id = order_id_min

    $stdout.puts "slice_counts: #{slice_counts} book_ids:#{[book_id_min, book_id_max]} order_ids:#{[order_id_min, order_id_max]} ##{part_num}"

    slice_counts.times do |slice_iter|
      order_attrs = []
      slice_qty.times do |order_iter|
        next if order_iter.zero?

        order_id = slice_qty*slice_iter + order_iter
        books_in_order_qty = book_order_qty.sample
        order_attrs.concat book_ids.sample(books_in_order_qty).zip(Array.new(books_in_order_qty, order_id))
      end
      file_name = "/tmp/books_orders_#{slice_iter}_#{part_num}.csv"
      CSV.open(file_name, "wb", write_headers: true, headers: %i[book_id order_id]) do |csv|
        order_attrs.each { |row| csv << row }
      end
      # # ts=Time.current
      # ActiveRecord::Base.connection.execute("COPY books_orders FROM '#{file_name}' DELIMITER ',' CSV HEADER;")
      # # $stdout.puts "#{Time.current-ts}s COPY##{part_num}"
      # # FileUtils.rm([file_name])
      # $stdout.puts "#{part_num}: #{slice_iter} of #{slice_counts}"
    rescue =>e
      $stdout.puts "#{e} stmnt_args: "
    end

    # stmnt = ""
    # Dir["/tmp/book_orders*.csv"].each do |file_name|
    #   stmnt+="COPY books_orders FROM '#{file_name}' DELIMITER ',' CSV HEADER;\n"
    # end
    # ActiveRecord::Base.connection.execute(stmnt)

    $stdout.puts "#{(Time.current-ts0).round}s #{pretty_count(order_qty)} ##{part_num} RoaringFkey::Order DONE"
  end

  def db_data_report
    $stdout.puts "Bench running on such data:"
    ActiveRecord::Base.connection_pool.with_connection do |connection|
      stmnt = <<~SQL
        SELECT
          nspname||'.'||relname||':'||regexp_replace(pg_size_pretty(reltuples::bigint), '(B| bytes)', E' rows')
        FROM pg_class C
        LEFT JOIN pg_namespace N ON (N.oid = C.relnamespace)
        WHERE
          nspname NOT IN ('pg_catalog', 'information_schema') AND
          relkind='r'
          and  (
            relname like '%books%' OR
            relname like '%orders%' OR
            relname like '%authors%' OR
            relname like '%suppliers%' OR
            relname like '%reviews%' OR
            relname like '%customers%'
          )
        ORDER BY CASE 
          WHEN relname like '%books%' AND relname!='books_orders' THEN 1 
          WHEN relname like '%authors%' THEN 2
          WHEN relname like '%suppliers%' THEN 3
          WHEN relname like '%customers%' THEN 4
          WHEN relname like '%reviews%' THEN 5
          WHEN relname like '%orders%' AND relname!='books_orders' THEN 6
          ELSE 7
        END;
      SQL
      $stdout.puts connection.select_values stmnt
    end
  end

  def get_parts_ids(qty, total_parts, part_num)
    [((qty/total_parts).to_i*(part_num-1)+1), ((qty/total_parts).to_i*part_num)]
  end
  
  def pretty_count(count_qty)
    ::ActiveSupport::NumberHelper::number_to_delimited((count_qty/1_000.0).round(1), delimiter: "_").to_s + "k"
  end

  def generate_random_funcs
    ActiveRecord::Base.connection.execute <<~SQL
      CREATE OR REPLACE FUNCTION random_int_array(dim integer, min integer, max integer) 
      RETURNS integer[] AS $BODY$
      begin
        return (select array_agg(round(random() * (max - min)) + min) from generate_series (0, dim));
      end
      $BODY$ LANGUAGE plpgsql;
    SQL
    ActiveRecord::Base.connection.execute <<~SQL
      CREATE OR REPLACE FUNCTION random_int(min integer, max integer) 
      RETURNS integer AS $BODY$
      begin
        return (select round(random() * (max - min)) + min);
      end
      $BODY$ LANGUAGE plpgsql;
    SQL
  end

  def generate_funcs_ar
    ActiveRecord::Base.connection.execute <<~SQL
      CREATE OR REPLACE FUNCTION fill_authors_ar(qty integer)
      RETURNS void AS $BODY$
      declare
        start_id int;
        ts  timestamp;
      begin
        start_id := COALESCE(max(id), 1) from authors;
        ts:=now();
        insert into authors(id, created_at, updated_at)
        select g.record_id,
               ts,
               ts
        from generate_series(start_id, start_id+qty, 1) as g(record_id);
      end
      $BODY$ LANGUAGE plpgsql;
    SQL
    ActiveRecord::Base.connection.execute <<~SQL
      CREATE OR REPLACE FUNCTION fill_suppliers_ar(qty integer)
      RETURNS void AS $BODY$
      declare
        start_id int;
        ts  timestamp;
      begin
        start_id :=COALESCE(max(id), 1) from suppliers;
        ts:=now();
        insert into suppliers(id, created_at, updated_at)
        select g.record_id,
               ts,
               ts
        from generate_series(start_id, start_id+qty, 1) as g(record_id);
      end
      $BODY$ LANGUAGE plpgsql;
    SQL
    ActiveRecord::Base.connection.execute <<~SQL
      CREATE OR REPLACE FUNCTION fill_customers_ar(qty integer)
      RETURNS void AS $BODY$
      declare
        start_id int;
        ts  timestamp;
      begin
        start_id :=COALESCE(max(id), 1) from customers;
        ts:=now();
        insert into customers(id, created_at, updated_at)
        select g.record_id,
               ts,
               ts
        from generate_series(start_id, start_id+qty, 1) as g(record_id);
      end
      $BODY$ LANGUAGE plpgsql;
    SQL
    ActiveRecord::Base.connection.execute <<~SQL
      CREATE OR REPLACE FUNCTION fill_orders_ar(qty integer, part_num integer, total_parts integer)
      RETURNS void AS $BODY$
      declare
        start_id int;
        ts  timestamp;
        customer_min_id int;
        customer_max_id int;
      begin
        start_id :=COALESCE(max(id), 1) from orders;
        ts:=now();
        customer_min_id := min(id) from customers;
        customer_max_id := max(id) from customers;
        insert into orders(id, status, total, customer_id, created_at, updated_at)
        select g.record_id,
               round(random()*3) status,
               round(random()*2000)*100 total,
               random_int(customer_min_id, customer_max_id) customer_id,
               ts,
               ts
        from generate_series((round(qty/total_parts)*(part_num-1)+1)::int, (round(qty/total_parts)*part_num)::int, 1) as g(record_id);
      end
      $BODY$ LANGUAGE plpgsql;
    SQL
    ActiveRecord::Base.connection.execute <<~SQL
      CREATE OR REPLACE FUNCTION fill_books_ar(qty integer)
      RETURNS void AS $BODY$
      declare
        start_id int;
        ts  timestamp;
        author_min_id int;
        author_max_id int;
        supplier_min_id int;
        supplier_max_id int;
        book_min_id int;
        book_max_id int;
        order_min_id int;
        order_max_id int;
      begin
        start_id :=COALESCE(max(id), 1)+1 from books;
        ts:=now();
        author_min_id := min(id) from authors;
        author_max_id := max(id) from authors;
        supplier_min_id := min(id) from suppliers;
        supplier_max_id := max(id) from suppliers;
        insert into books(id, views, year_published, author_id, supplier_id, created_at, updated_at)
        select g.record_id,
               NULL,
               NULL,
               random_int(author_min_id, author_max_id),
               random_int(supplier_min_id, supplier_max_id),
               ts,
               ts
        from generate_series(start_id, start_id+qty, 1) as g(record_id);
      end
      $BODY$ LANGUAGE plpgsql;
    SQL
    ActiveRecord::Base.connection.execute <<~SQL
      CREATE OR REPLACE FUNCTION fill_books_orders(book_qty integer, orders_qty integer, part_num integer)
      RETURNS void AS $BODY$
      declare
        ts  timestamp;
        book_min_id int;
        book_max_id int;
        total_parts int:=8;
      begin      
        ts:=now();
        book_min_id := min(id) from books;
        book_max_id := book_min_id+book_qty;

        insert into books_orders(book_id, order_id)
        select unnest(random_int_array(trunc(random() * 15)::int, book_min_id, book_max_id)),
               order_id
        from generate_series((round(orders_qty/total_parts)*(part_num-1)+1)::int, 
             (round(orders_qty/total_parts)*part_num)::int, 1) as g(order_id);     
    
      end
      $BODY$ LANGUAGE plpgsql;
    SQL

    ActiveRecord::Base.connection.execute <<~SQL
      CREATE OR REPLACE FUNCTION fill_books_orders_sliced(
        book_qty integer, orders_qty integer, part_num integer, total_parts integer)
      RETURNS void AS $BODY$
      declare
        ts  timestamp;
        book_min_id int;
        book_max_id int;
        start_id_iteration int;
        iterator_loops CURSOR FOR SELECT record_id FROM 
          generate_series((round(orders_qty/total_parts)*(part_num-1)+1)::int, 
             (round(orders_qty/total_parts)*part_num)::int, 20000) as g(record_id); 
      begin      
        ts:=now();
        book_min_id := min(id) from books;
        book_max_id := book_min_id+book_qty;

        FOR start_id_iteration IN iterator_loops 
        LOOP
                    insert into books_orders(book_id, order_id)
                    select unnest(random_int_array(trunc(random() * 15)::int, book_min_id, book_max_id)),
                           order_id
                    from generate_series(start_id_iteration.record_id, 
                          least(start_id_iteration.record_id+20000, 
                          (round(orders_qty/total_parts)*part_num)::int), 1) as g(order_id);
 
        END LOOP; 

      end
      $BODY$ LANGUAGE plpgsql;
    SQL

    ActiveRecord::Base.connection.execute <<~SQL
      CREATE OR REPLACE FUNCTION fill_reviews_ar(qty integer, part_num integer, total_parts integer)
      RETURNS void AS $BODY$
      declare
        ts  timestamp;
        customer_min_id int;
        customer_max_id int;
        book_min_id int;
        book_max_id int;   
      begin       
        ts:=now();
        customer_min_id := min(id) from customers;
        customer_max_id := max(id) from customers;
        book_min_id := min(id) from books;
        book_max_id := max(id) from books;
        insert into reviews(id, rating, state, book_id, customer_id, created_at, updated_at)
        select g.record_id,
               round(random()*5),
               round(random()*2),
               random_int(book_min_id, book_max_id),
               random_int(customer_min_id, customer_max_id),
               ts,
               ts
        from generate_series((round(qty/total_parts)*(part_num-1)+1)::int, (round(qty/total_parts)*part_num)::int, 1) as g(record_id);
      end
      $BODY$ LANGUAGE plpgsql;
    SQL
  end

  def generate_funcs_roaring_fkey
    ActiveRecord::Base.connection.execute <<~SQL
      CREATE OR REPLACE FUNCTION fill_roaring_fkey_authors(qty integer, books_qty integer)
      RETURNS void AS $BODY$
      declare
        start_id int;
        ts  timestamp;
      begin
        start_id :=COALESCE(max(id), 1)+1 from roaring_fkey_authors;
        ts:=now();
        insert into roaring_fkey_authors(id, book_ids, created_at, updated_at)
        select g.record_id,
               rb_build(random_int_array(trunc(random() * 23)::int, 1, books_qty)),
               ts,
               ts
        from generate_series(start_id, start_id+qty, 1) as g(record_id);
      end
      $BODY$ LANGUAGE plpgsql;
    SQL
    ActiveRecord::Base.connection.execute <<~SQL
      CREATE OR REPLACE FUNCTION fill_roaring_fkey_suppliers(qty integer, books_qty integer)
      RETURNS void AS $BODY$
      declare
        start_id int;
        ts  timestamp;
      begin
        start_id :=COALESCE(max(id), 1)+1 from roaring_fkey_suppliers;
        ts:=now();
        insert into roaring_fkey_suppliers(id, book_ids, created_at, updated_at)
        select g.record_id,
               rb_build(random_int_array(trunc(random() * 23)::int, 1, books_qty)),
               ts,
               ts
        from generate_series(start_id, start_id+qty, 1) as g(record_id);
      end
      $BODY$ LANGUAGE plpgsql;
    SQL
    ActiveRecord::Base.connection.execute <<~SQL
      CREATE OR REPLACE FUNCTION fill_roaring_fkey_books(
        qty integer, reviews_qty integer, orders_qty integer
      )
      RETURNS void AS $BODY$
      declare
        start_id int;
        ts  timestamp;
      begin
        start_id :=COALESCE(max(id), 1)+1 from roaring_fkey_books;
        ts:=now();
        insert into roaring_fkey_books(id, review_ids, order_ids, created_at, updated_at)
        select g.record_id,
               rb_build(random_int_array(trunc(random() * 23)::int, 1, reviews_qty)),  
               rb_build(random_int_array(trunc(random() * 15)::int, 1, orders_qty)),  
               ts,
               ts
        from generate_series(start_id, start_id+qty, 1) as g(record_id);
      end
      $BODY$ LANGUAGE plpgsql;
    SQL
    ActiveRecord::Base.connection.execute <<~SQL
      CREATE OR REPLACE FUNCTION fill_roaring_fkey_customers(
        qty integer, reviews_qty integer, orders_qty integer
      )
      RETURNS void AS $BODY$
      declare
        start_id int;
        ts  timestamp;
      begin
        start_id :=COALESCE(max(id), 1)+1 from roaring_fkey_customers;
        ts:=now();
        insert into roaring_fkey_customers(id, review_ids, order_ids, created_at, updated_at)
        select g.record_id,
               rb_build(random_int_array(trunc(random() * 23)::int, 1, reviews_qty)),  
               rb_build(random_int_array(trunc(random() * 15)::int, 1, orders_qty)),  
               ts,
               ts
        from generate_series(start_id, start_id+qty, 1) as g(record_id);
      end
      $BODY$ LANGUAGE plpgsql;
    SQL
    ActiveRecord::Base.connection.execute <<~SQL
      CREATE OR REPLACE FUNCTION fill_roaring_fkey_reviews(
        qty integer, part_num integer, total_parts integer
      )
      RETURNS void AS $BODY$
      declare
        book_min_id int;
        book_max_id int;
        customer_min_id int;
        customer_max_id int;
        ts  timestamp;     
      begin
        book_min_id := min(id) from roaring_fkey_books;
        book_max_id := max(id) from roaring_fkey_books;
        customer_min_id := min(id) from roaring_fkey_customers;
        customer_max_id := max(id) from roaring_fkey_customers;
        ts:=now();
        insert into roaring_fkey_reviews(id, rating, state, roaring_fkey_book_id, roaring_fkey_customer_id, created_at, updated_at)
        select g.record_id,
               round(random()*5),
               round(random()*2),
               random_int(book_min_id, book_max_id),
               random_int(customer_min_id, customer_max_id),
               ts,
               ts
        from generate_series((round(qty/total_parts)*(part_num-1)+1)::int, (round(qty/total_parts)*part_num)::int, 1) as g(record_id);
      end
      $BODY$ LANGUAGE plpgsql;
    SQL
    ActiveRecord::Base.connection.execute <<~SQL
      CREATE OR REPLACE FUNCTION fill_roaring_fkey_orders(
        qty integer, books_qty integer, part_num integer, total_parts integer
      )
      RETURNS void AS $BODY$
      declare
        ts  timestamp;
        customer_min_id int;
        customer_max_id int; 
      begin
        ts:=now();
        customer_min_id := min(id) from roaring_fkey_customers;
        customer_max_id := max(id) from roaring_fkey_customers;

        insert into roaring_fkey_orders(id, total, book_ids, roaring_fkey_customer_id, created_at, updated_at)
        select g.order_id,
               round(random()*2000)*100, 
               rb_build(random_int_array(trunc(random() * 15)::int, 1, books_qty)),
               random_int(customer_min_id, customer_max_id),
               ts,
               ts
        from generate_series((round(qty/total_parts)*(part_num-1)+1)::int, (round(qty/total_parts)*part_num)::int, 1) as g(order_id);
        
      end
      $BODY$ LANGUAGE plpgsql;
    SQL
  end

  def create_ar_records(author_qty, book_qty, supplier_qty, customer_qty, review_qty, order_qty)
    ts = Time.current
    sql_gen('fill_authors_ar', author_qty)
    sql_gen('fill_suppliers_ar', supplier_qty)
    sql_gen('fill_customers_ar', customer_qty)

    ts_parallel = Time.current
    # puts "before all:#{ts}"
    threads = [
      Thread.new do
        sql_gen_ex('fill_orders_ar', order_qty, 1, 4)
      end,
      Thread.new do
        sql_gen_ex('fill_orders_ar', order_qty, 2, 4)
      end,
      Thread.new do
        sql_gen_ex('fill_orders_ar', order_qty, 3, 4)
      end,
      Thread.new do
        sql_gen_ex('fill_orders_ar', order_qty, 4, 4)
      end,
      Thread.new do
        sql_gen('fill_books_ar', book_qty)
      end,
      Thread.new do
        sql_gen_ex('fill_reviews_ar', review_qty, 1, 4)
      end,
      Thread.new do
        sql_gen_ex('fill_reviews_ar', review_qty, 2, 4)
      end,
      Thread.new do
        sql_gen_ex('fill_reviews_ar', review_qty, 3, 4)
      end,
      Thread.new do
        sql_gen_ex('fill_reviews_ar', review_qty, 4, 4)
      end
    ]
    threads.each(&:join)
    puts "after fill_orders_ar*4, fill_books_ar, fill_reviews_ar*4:#{Time.current-ts_parallel}s"

    ts_parallel = Time.current

    threads = [
      Thread.new do
        sql_gen_ex('fill_books_orders', book_qty, order_qty, 1)
      end,
      Thread.new do
        sql_gen_ex('fill_books_orders', book_qty, order_qty, 2)
      end,
      Thread.new do
        sql_gen_ex('fill_books_orders', book_qty, order_qty, 3)
      end,
      Thread.new do
        sql_gen_ex('fill_books_orders', book_qty, order_qty, 4)
      end,
      Thread.new do
        sql_gen_ex('fill_books_orders', book_qty, order_qty, 5)
      end,
      Thread.new do
        sql_gen_ex('fill_books_orders', book_qty, order_qty, 6)
      end,
      Thread.new do
        sql_gen_ex('fill_books_orders', book_qty, order_qty, 7)
      end,
      Thread.new do
        sql_gen_ex('fill_books_orders', book_qty, order_qty, 8)
      end
    ]
    threads.each(&:join)
    puts "after fill_books_orders:#{Time.current-ts_parallel}s"

    $stdout.puts "⁂#⁂#⁂ Done classic AR records - in #{Time.current - ts}s"
  end

  def generate_db_schema_models_files
    # model.reflect_on_all_associations.select { |a| a.is_a?(ActiveRecord::Reflection::BelongsToReflection) }.map(&:name)
  end

  def bench_stage(ar_rel, rb_rel)
    Benchmark.ips do |x|
      x.config(time: 10, warmup: 5)

      $stdout.puts "AR:"
      $stdout.puts ar_rel.to_sql
      $stdout.puts ar_rel.explain

      x.report("ActiveRecord") do
        ar_rel.to_a
      end

      $stdout.puts "Roaringbitmap:"
      $stdout.puts rb_rel.to_sql
      $stdout.puts rb_rel.explain

      x.report("RoaringFkey") do
        rb_rel.to_a
      end

      x.compare!
    end
  end
end

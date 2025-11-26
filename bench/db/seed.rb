# TPC-H Database Seed Script
# This script loads data from CSV files into the TPC-H tables

# Disable foreign key constraints temporarily for faster loading
ActiveRecord::Base.connection.execute("SET session_replication_role = replica;")

# Load data into tables in the correct order to satisfy foreign key constraints

# Load PART table
puts "Loading PART data..."
copy_sql = <<-SQL
  COPY part FROM '#{Rails.root.join('db', 'data', 'part.csv')}' 
  WITH (FORMAT csv, DELIMITER '|');
SQL
ActiveRecord::Base.connection.execute(copy_sql)
puts "PART data loaded successfully."

# Load REGION table
puts "Loading REGION data..."
copy_sql = <<-SQL
  COPY region FROM '#{Rails.root.join('db', 'data', 'region.csv')}' 
  WITH (FORMAT csv, DELIMITER '|');
SQL
ActiveRecord::Base.connection.execute(copy_sql)
puts "REGION data loaded successfully."

# Load NATION table (depends on REGION)
puts "Loading NATION data..."
copy_sql = <<-SQL
  COPY nation FROM '#{Rails.root.join('db', 'data', 'nation.csv')}' 
  WITH (FORMAT csv, DELIMITER '|');
SQL
ActiveRecord::Base.connection.execute(copy_sql)
puts "NATION data loaded successfully."

# Load SUPPLIER table (depends on NATION)
puts "Loading SUPPLIER data..."
copy_sql = <<-SQL
  COPY supplier FROM '#{Rails.root.join('db', 'data', 'supplier.csv')}' 
  WITH (FORMAT csv, DELIMITER '|');
SQL
ActiveRecord::Base.connection.execute(copy_sql)
puts "SUPPLIER data loaded successfully."

# Load CUSTOMER table (depends on NATION)
puts "Loading CUSTOMER data..."
copy_sql = <<-SQL
  COPY customer FROM '#{Rails.root.join('db', 'data', 'customer.csv')}' 
  WITH (FORMAT csv, DELIMITER '|');
SQL
ActiveRecord::Base.connection.execute(copy_sql)
puts "CUSTOMER data loaded successfully."

# Load PARTSUPP table (depends on PART and SUPPLIER)
puts "Loading PARTSUPP data..."
copy_sql = <<-SQL
  COPY partsupp FROM '#{Rails.root.join('db', 'data', 'partsupp.csv')}' 
  WITH (FORMAT csv, DELIMITER '|');
SQL
ActiveRecord::Base.connection.execute(copy_sql)
puts "PARTSUPP data loaded successfully."

# Load ORDERS table (depends on CUSTOMER)
puts "Loading ORDERS data..."
copy_sql = <<-SQL
  COPY orders FROM '#{Rails.root.join('db', 'data', 'orders.csv')}' 
  WITH (FORMAT csv, DELIMITER '|');
SQL
ActiveRecord::Base.connection.execute(copy_sql)
puts "ORDERS data loaded successfully."

# Load LINEITEM table (depends on ORDERS and PARTSUPP)
puts "Loading LINEITEM data..."
copy_sql = <<-SQL
  COPY lineitem FROM '#{Rails.root.join('db', 'data', 'lineitem.csv')}' 
  WITH (FORMAT csv, DELIMITER '|');
SQL
ActiveRecord::Base.connection.execute(copy_sql)
puts "LINEITEM data loaded successfully."

# Re-enable foreign key constraints
ActiveRecord::Base.connection.execute("SET session_replication_role = DEFAULT;")

puts "All TPC-H data loaded successfully!"
puts "Data loaded from: #{Rails.root.join('db', 'data')}"

# Print row counts for verification
tables = ['part', 'region', 'nation', 'supplier', 'customer', 'partsupp', 'orders', 'lineitem']
tables.each do |table|
  count = ActiveRecord::Base.connection.execute("SELECT COUNT(*) FROM #{table}").first['count']
  puts "#{table.upcase}: #{count} rows"
end
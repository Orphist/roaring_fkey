# frozen_string_literal: true

module DatabaseLoader
  # Load CSV data into database using COPY command
  def self.copy_from_csv(table_name, columns, csv_path)
    sql = generate_copy_sql(table_name, columns, csv_path)
    
    begin
      # Execute COPY command
      result = ActiveRecord::Base.connection.execute(sql)
      
      # Get row count after loading
      row_count = ActiveRecord::Base.connection.select_value(
        "SELECT COUNT(*) FROM #{table_name}"
      )
      
      puts "✓ Loaded data into #{table_name}: #{row_count} rows total"
      
      true
    rescue => e
      puts "✗ Error loading data into #{table_name}: #{e.message}"
      puts "SQL: #{sql}"
      false
    end
  end
  
  # Generate COPY SQL command
  def self.generate_copy_sql(table_name, columns, csv_path)
    column_list = columns.join(', ')
    
    # Use absolute path for PostgreSQL
    absolute_path = File.absolute_path(csv_path)
    
    <<-SQL
COPY #{table_name} (#{column_list})
FROM '#{absolute_path}'
DELIMITER '|'
CSV;
    SQL
  end
  
  # Check if table exists
  def self.table_exists?(table_name)
    ActiveRecord::Base.connection.table_exists?(table_name)
  end
  
  # Get current row count for table
  def self.get_row_count(table_name)
    return 0 unless table_exists?(table_name)
    
    begin
      ActiveRecord::Base.connection.select_value(
        "SELECT COUNT(*) FROM #{table_name}"
      ).to_i
    rescue => e
      puts "Warning: Could not get row count for #{table_name}: #{e.message}"
      0
    end
  end
  
  # Truncate table before loading (optional)
  def self.truncate_table(table_name)
    return unless table_exists?(table_name)
    
    begin
      ActiveRecord::Base.connection.execute("TRUNCATE TABLE #{table_name} RESTART IDENTITY CASCADE")
      puts "Truncated table: #{table_name}"
    rescue => e
      puts "Warning: Could not truncate table #{table_name}: #{e.message}"
    end
  end
  
  # Disable triggers and indexes for faster loading
  def self.optimize_for_loading(table_name)
    return unless table_exists?(table_name)
    
    begin
      # Disable triggers (if any)
      ActiveRecord::Base.connection.execute("ALTER TABLE #{table_name} DISABLE TRIGGER ALL")
      
      # Note: Index handling would be table-specific
      # This is a placeholder for optimization logic
    rescue => e
      puts "Warning: Could not optimize table #{table_name} for loading: #{e.message}"
    end
  end
  
  # Re-enable triggers after loading
  def self.restore_normal_operations(table_name)
    return unless table_exists?(table_name)
    
    begin
      # Re-enable triggers
      ActiveRecord::Base.connection.execute("ALTER TABLE #{table_name} ENABLE TRIGGER ALL")
    rescue => e
      puts "Warning: Could not restore normal operations for #{table_name}: #{e.message}"
    end
  end
  
  # Verify data integrity after loading
  def self.verify_data_integrity(table_name, expected_min_rows = 0)
    return false unless table_exists?(table_name)
    
    row_count = get_row_count(table_name)
    
    if row_count < expected_min_rows
      puts "✗ Data integrity issue for #{table_name}: only #{row_count} rows, expected at least #{expected_min_rows}"
      return false
    end
    
    puts "✓ Data integrity verified for #{table_name}: #{row_count} rows"
    true
  end
end
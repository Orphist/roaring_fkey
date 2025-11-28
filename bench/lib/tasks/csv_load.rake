# frozen_string_literal: true

require_relative '../support/schema_parser'
require_relative '../support/file_processor'
require_relative '../support/database_loader'

namespace :csv do
  desc "Load CSV data from generated files into database"
  task load_from_files: :environment do
    puts "Starting CSV data loading process..."
    puts "Time: #{Time.now}"
    puts "=" * 50
    
    begin
      # Validate schema files exist
      SchemaParser.validate_schema_files
      puts "✓ Schema validation passed"
      
      # Get tables in processing order
      tables_to_process = SchemaParser.get_tables_processing_order
      
      puts "Tables to process: #{tables_to_process.join(', ')}"
      puts
      
      total_files_processed = 0
      total_errors = 0
      
      tables_to_process.each do |table_name|
        puts "Processing table: #{table_name}"
        puts "-" * 30
        
        begin
          processed_files, errors = process_table_data(table_name)
          total_files_processed += processed_files
          total_errors += errors
        rescue => e
          puts "✗ Failed to process table #{table_name}: #{e.message}"
          total_errors += 1
        end
        
        puts
      end
      
      puts "=" * 50
      puts "CSV Loading Summary:"
      puts "Total files processed: #{total_files_processed}"
      puts "Total errors: #{total_errors}"
      puts "Completed at: #{Time.now}"
      
      if total_errors > 0
        puts "⚠️  Process completed with #{total_errors} errors"
        exit 1
      else
        puts "✓ All data loaded successfully"
      end
      
    rescue => e
      puts "✗ Fatal error during CSV loading: #{e.message}"
      puts e.backtrace if ENV['DEBUG']
      exit 1
    end
  end
  
  desc "Show table statistics after loading"
  task show_stats: :environment do
    tables = SchemaParser.get_tables_processing_order
    
    puts "Table Statistics:"
    puts "=" * 30
    
    tables.each do |table_name|
      row_count = DatabaseLoader.get_row_count(table_name)
      puts "#{table_name.ljust(20)}: #{row_count.to_s.rjust(12)} rows"
    end
  end
  
  desc "Truncate all tables before loading"
  task truncate_tables: :environment do
    tables = SchemaParser.get_tables_processing_order
    
    puts "Truncating tables..."
    
    # Process in reverse dependency order for truncation
    tables.reverse.each do |table_name|
      DatabaseLoader.truncate_table(table_name)
    end
    
    puts "✓ All tables truncated"
  end
  
  desc "Full reload: truncate, load, and show stats"
  task full_reload: [:truncate_tables, :load_from_files, :show_stats]
  
  private
  
  def self.process_table_data(table_name)
    processed_files = 0
    errors = 0
    
    # Check if table directory exists
    unless FileProcessor.table_directory_exists?(table_name)
      puts "⚠️  No data directory found for table: #{table_name}"
      return [processed_files, errors]
    end
    
    # Load schema
    schema = SchemaParser.load_schema(table_name)
    columns = schema[:columns].map { |col| col[:name] }
    puts "✓ Schema loaded: #{columns.join(', ')}"
    
    # Check if table exists in database
    unless DatabaseLoader.table_exists?(table_name)
      puts "⚠️  Table #{table_name} does not exist in database, skipping..."
      return [processed_files, errors]
    end
    
    # Get initial row count
    initial_count = DatabaseLoader.get_row_count(table_name)
    puts "Initial row count: #{initial_count}"
    
    # Optimize table for loading
    DatabaseLoader.optimize_for_loading(table_name)
    
    # Collect and process zip files
    table_path = "bench/lib/arunma__datagen/output_data/#{table_name}.csv"
    zip_files = FileProcessor.collect_zip_files(table_path)
    
    if zip_files.empty?
      puts "⚠️  No zip files found for table: #{table_name}"
      return [processed_files, errors]
    end
    
    puts "Found #{zip_files.length} zip files to process"
    
    zip_files.each_with_index do |zip_file, index|
      puts "Processing file #{index + 1}/#{zip_files.length}: #{File.basename(zip_file)}"
      
      begin
        # Extract zip file
        csv_file = FileProcessor.extract_zip_file(zip_file)
        
        # Get file size for logging
        file_size = FileProcessor.get_file_size(csv_file)
        puts "  Extracted CSV: #{File.basename(csv_file)} (#{file_size} bytes)"
        
        # Load data via COPY
        if DatabaseLoader.copy_from_csv(table_name, columns, csv_file)
          processed_files += 1
          puts "  ✓ Loaded successfully"
        else
          errors += 1
          puts "  ✗ Loading failed"
        end
        
      rescue => e
        puts "  ✗ Error processing file: #{e.message}"
        errors += 1
      ensure
        # Clean up extracted CSV file
        if csv_file && File.exist?(csv_file)
          FileProcessor.cleanup_csv_file(csv_file)
          puts "  Cleaned up extracted file"
        end
      end
    end
    
    # Restore normal operations
    DatabaseLoader.restore_normal_operations(table_name)
    
    # Verify data integrity
    final_count = DatabaseLoader.get_row_count(table_name)
    rows_added = final_count - initial_count
    
    puts "Final row count: #{final_count} (+#{rows_added})"
    
    # Basic integrity check
    DatabaseLoader.verify_data_integrity(table_name, initial_count)
    
    [processed_files, errors]
  end
end
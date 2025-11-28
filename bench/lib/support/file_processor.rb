# frozen_string_literal: true

require 'zip'

module FileProcessor
  # Collect all zip files for a given table
  def self.collect_zip_files(table_path)
    zip_pattern = File.join(table_path, "*.csv.zip")
    zip_files = Dir.glob(zip_pattern).sort
    
    if zip_files.empty?
      puts "Warning: No zip files found in #{table_path}"
    end
    
    zip_files
  end
  
  # Extract a zip file to the same directory
  def self.extract_zip_file(zip_path)
    directory = File.dirname(zip_path)
    
    begin
      Zip::File.open(zip_path) do |zip_file|
        zip_file.each do |entry|
          # Extract only CSV files
          if entry.name.end_with?('.csv')
            extracted_path = File.join(directory, File.basename(entry.name))
            
            # Extract file
            entry.extract(extracted_path) { true }
            
            return extracted_path
          end
        end
      end
      
      raise "No CSV file found in zip: #{zip_path}"
    rescue => e
      raise "Error extracting zip file #{zip_path}: #{e.message}"
    end
  end
  
  # Clean up extracted CSV file
  def self.cleanup_csv_file(csv_path)
    if File.exist?(csv_path)
      begin
        File.delete(csv_path)
      rescue => e
        puts "Warning: Could not delete CSV file #{csv_path}: #{e.message}"
      end
    end
  end
  
  # Check if table directory exists
  def self.table_directory_exists?(table_name)
    table_path = "bench/lib/arunma__datagen/output_data/#{table_name}.csv"
    Dir.exist?(table_path)
  end
  
  # Get file size for logging
  def self.get_file_size(file_path)
    File.exist?(file_path) ? File.size(file_path) : 0
  end
  
  # Count lines in CSV file (for progress reporting)
  def self.count_csv_lines(csv_path)
    return 0 unless File.exist?(csv_path)
    
    begin
      # Simple line count - may be slow for very large files
      File.foreach(csv_path).count
    rescue => e
      puts "Warning: Could not count lines in #{csv_path}: #{e.message}"
      0
    end
  end
end
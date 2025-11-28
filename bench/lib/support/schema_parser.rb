# frozen_string_literal: true

require 'yaml'

module SchemaParser
  # Parse YAML schema file and return table and column information
  def self.load_schema(table_name)
    schema_path = "bench/lib/arunma__datagen/schemas/schema_#{table_name}.yaml"
    
    unless File.exist?(schema_path)
      raise "Schema file not found: #{schema_path}"
    end
    
    begin
      schema_content = YAML.load_file(schema_path)
      dataset = schema_content['dataset']
      
      {
        table_name: dataset['name'],
        columns: dataset['columns'].map do |col|
          {
            name: col['name'],
            type: col['dtype'],
            not_null: col['not_null'] || false
          }
        end
      }
    rescue => e
      raise "Error parsing schema file #{schema_path}: #{e.message}"
    end
  end
  
  # Get all available table names from schema directory
  def self.get_all_table_names
    schema_dir = "bench/lib/arunma__datagen/schemas"
    Dir.glob(File.join(schema_dir, "schema_*.yaml")).map do |file|
      File.basename(file, '.yaml').sub('schema_', '')
    end.sort
  end
  
  # Get tables in processing order (respecting dependencies)
  def self.get_tables_processing_order
    # Define dependency order for referential integrity
    # Tables with no foreign keys first
    # Note: Some schema files have typos in names (authors vs authors, customers vs customers)
    [
      'authors',
      'customers',
      'suppliers',
      'books',
      'orders',
      'reviews',
      'books_orders'
    ]
  end
  
  # Validate that all schema files exist for tables in processing order
  def self.validate_schema_files
    missing_files = []
    
    get_tables_processing_order.each do |table|
      schema_path = "bench/lib/arunma__datagen/schemas/schema_#{table}.yaml"
      unless File.exist?(schema_path)
        missing_files << schema_path
      end
    end
    
    unless missing_files.empty?
      raise "Missing schema files: #{missing_files.join(', ')}"
    end
    
    true
  end
end
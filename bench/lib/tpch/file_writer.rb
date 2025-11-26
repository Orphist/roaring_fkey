# frozen_string_literal: true

module Tpch
  # Handles pipe-delimited file output
  # Writes rows in format: field1|field2|field3|
  # Note trailing pipe after last field
  class FileWriter
    attr_reader :file_path

    def initialize(output_dir:, table_name:, segment:)
      @output_dir = output_dir
      @table_name = table_name
      @segment = segment
      @file_path = File.join(@output_dir, "#{@table_name}.tbl.#{@segment}")
    end

    def write_rows(rows)
      File.open(@file_path, 'w') do |file|
        rows.each do |row|
          file.puts(format_row(row))
        end
      end
    end

    def open_for_streaming
      @file = File.open(@file_path, 'w')
      yield self
    ensure
      @file&.close
    end

    def write_chunk(chunk)
      chunk.each { |row| @file.puts(format_row(row)) }
      @file.flush
    end

    private

    def format_row(row)
      if row.is_a?(Hash)
        values = row.values
      elsif row.is_a?(Array)
        values = row
      else
        raise ArgumentError, "Row must be Hash or Array, got #{row.class}"
      end

      values.map { |value| escape_field(value) }.join('|') + '|'
    end

    def escape_field(value)
      # TPC-H data doesn't require complex escaping
      # Just convert to string and handle nil values
      value.nil? ? '' : value.to_s
    end
  end
end
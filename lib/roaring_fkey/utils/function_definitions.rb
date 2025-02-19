# frozen_string_literal: true

module RoaringFkey
  module Utils
    class FunctionDefinition < Struct.new(:name, :signature); end

    module FunctionDefinitions
      class << self
        def from_fs
          function_paths = Dir.glob(File.join(__dir__, "..", "..", "generators", "roaring_fkey", "install", "functions", "*.sql"))
          function_paths.map do |path|
            name = path.match(/([^\/]+)\.sql/)[1]

            file = File.open(path)
            func_definition_line = file.readlines.select { |line| line.match(/.*CREATE FUNCTION.*/) }[0]
            signature = parse_signature(func_definition_line)
            FunctionDefinition.new(name, signature)
          end
        end

        def from_db
          query = <<~SQL
            SELECT pp.proname, pg_get_functiondef(pp.oid) AS definition
            FROM pg_proc pp
            WHERE pp.proname like 'roaring_fkey_%'
            ORDER BY pp.oid;
          SQL
          ActiveRecord::Base.connection.execute(query).map do |row|
            FunctionDefinition.new(row["proname"], nil)
          end
        end

        private

        def parse_signature(line)
          parameters = line.match(/.*CREATE FUNCTION\s+[\w_]+\((.*)\)/i)[1]
          parameters.split(/\s*,\s*/).map { |param| param.split(/\s+/, 2).last.sub(/\s+DEFAULT .*$/, "") }.join(", ")
        end
      end
    end
  end
end

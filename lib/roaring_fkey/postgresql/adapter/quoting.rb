# frozen_string_literal: true

module RoaringFkey
  module PostgreSQL
    module Adapter
      module Quoting

        Name = ActiveRecord::ConnectionAdapters::PostgreSQL::Name
        Column = ActiveRecord::ConnectionAdapters::PostgreSQL::Column
        ColumnDefinition = ActiveRecord::ConnectionAdapters::ColumnDefinition

        # Quotes type names for use in SQL queries.
        def quote_type_name(string, schema = nil)
          name_schema, table = string.to_s.scan(/[^".\s]+|"[^"]*"/)
          if table.nil?
            table = name_schema
            name_schema = nil
          end

          schema = schema || name_schema || 'public'
          Name.new(schema, table).quoted
        end

        def quote_default_expression(value, column)
          return super unless value.class <= Array &&
            ((column.is_a?(ColumnDefinition) && column.dig(:options, :array)) ||
            (column.is_a?(Column) && column.array?))

          type = column.is_a?(Column) ? column.sql_type_metadata.sql_type : column.sql_type
          quote(value) + '::' + type
        end

        private

          def _quote(value)
            case value
              when Array
                # p ['array'*3]
                # puts caller.map { |v| v.match(/roaring.*\/(.*)/).try(:[], 1).to_s.strip }.reject(&:blank?).join("\n")
                # values = value.map(&method(:quote))
                "ARRAY[#{value.map(&method(:quote)).join(','.freeze)}]"
              # when ::RoaringFkey::PostgreSQL::Adapter::OID::Roaringbitmap::Datata
              when ::ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Roaringbitmap::Datata
                # p ["*Roarrrr!!!*"*3, "_quote_roaringbiymap"]
                # binding.pry #unless value.values.is_a?(Array)
                # "rb_to_array(#{value.values.flatten.join(',')})"
                # "ARRAY[#{value.values.join(','.freeze)}]"
                # value._string
                value.to_s
              else
                super
            end
          end

          def _type_cast(value)
            return super unless value.is_a?(Array)
            value.map(&method(:quote)).join(','.freeze)
          end

        # def type_casted_binds(binds)
        #   unless binds.empty?
        #     p binds
        #     binding.pry
        #   end
        #   case binds.first
        #     when RoaringbitmapType::Datata
        #       binding.pry
        #       binds.map { |column, value| type_cast(value, column) }
        #   else
        #     super
        #   end
        # end
      end
    end
  end
end

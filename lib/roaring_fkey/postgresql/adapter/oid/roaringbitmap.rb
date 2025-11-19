# frozen_string_literal: true

module Casting
  def cast_to_array(value)
    return value if value.is_a?(Array)

    quoted_value = quote_value(value)
    value_sql = <<~SQL
      SELECT rb_to_array(#{quoted_value});
    SQL
    casted_values = ActiveRecord::Base.connection.select_all(value_sql.squish)
    casted_values = casted_values.to_a.flat_map { |o| o.flat_map { |k, v| casted_values.column_types[k].cast v } }
    casted_values
  end

  def cast_from_array(value)
    objects = value.select { |o| o.respond_to?(:id) }
    values = (value - objects + objects.map(&:id)).compact

    value_sql = <<~SQL
      SELECT rb_build(ARRAY[#{values.join(',')}]);
    SQL
    ActiveRecord::Base.connection.select_values(value_sql.squish)[0]
  end

  def quote_value(value)
    if value.is_a?(Array)
      return cast_from_array(value.flatten)
    end

    if value.start_with?("'") && value.end_with?("'")
      unquoted_value = value[1..-2]
      unquoted_value.gsub!('""', '"')
      unquoted_value.gsub!('\\\\', '\\')
      "'#{unquoted_value}'"
    else
      "'#{value}'"
    end
  end
end

# Define custom ActiveRecord type with logic for retrieving and saving values into database
# ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Roaringbitmap
module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID
        class Roaringbitmap < ActiveModel::Type::Value
          include Casting

          def type
            :roaringbitmap
          end

          class Datata #< ::Roaring::Bitmap
            include Casting

            def initialize(value)
              @value = value
            end

            def inspect
              "@value = #{@value}"
            end

            def to_s
              if @value.is_a?(::Array)
                @value.join(',')
              else
                quote_value(@value)
              end
            end

            def binary?
              /[01]*/.match?(@value)
            end

            def hex?
              /[0-9A-F]*/i.match?(@value)
            end

            def uniq
              @value
              self
            end

            def compact
              @value
              self
            end

            def size
              @value.size
            end
            alias :count :size

            def <<(*values)
              if @value.is_a?(Array)
                @value = (@value + [values]).flatten.uniq
              elsif @value.is_a?(String) && @value.match?(/\\x3a3.*/)
                @value = cast_from_array((cast_to_array(@value) + values).flatten.uniq)
              else
                @value = cast_from_array(@value.split(',').map(&:to_i) + [values].flatten)
              end
              self
            end

            def +(*values)
              if @value.is_a?(Array)
                @value = (@value + [values]).flatten.uniq
              elsif @value.is_a?(String) && @value.match?(/\\x3a3.*/)
                @value = cast_from_array(cast_to_array(@value) + values)
              else
                @value = cast_from_array(@value.split(',').map(&:to_i) + [values].flatten)
              end
              self
            end

            private
              attr_reader :value
          end

          # Prepare value to be saved into database
          def serialize(value)
            return nil if value.blank?

            case value
            when ::Array
              cast_from_array(value.flatten)
            end
          end

          # Parse data either from user or database
          def deserialize(value)
            return [] if value.blank?

            case value
            when Datata
              value
            when ::String
              cast_to_array(value)
            when ::Array
              cast_to_array(value)
            when ::Numeric
              value
            else
              raise NotImplementedError, "deserialize(value):Don't know how to cast #{value.class} #{value.inspect} into Roaringbitmap"
            end
          end

          # Parse data from user input
          def cast(value)
            return nil if value.nil?

            case value
            when ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Roaringbitmap
              # casted_values = cast_to_array(value)
              # binding.pry
              # Datata.new(casted_values)
              [:ca_roaringbitmap]
            when Datata
              value
            when ::String
              deserialize(value)
            when ::Array
              value.flatten
            else
              binding.pry
              raise NotImplementedError, "cast(value):Don't know how to cast #{value.class} #{value.inspect} into Roaringbitmap"
            end
          end

          # Parse data either from database or user input.
          # Convenience method that replaces both `deserialize` and `cast`. Also handles nils for us.
          def cast_value(value)
            case value
            when ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Roaringbitmap
              value
            when String
              currency, amount = value.match(/\A\("?(\w+)"?,(\d+(?:\.\d+)?)\)\z/).captures
              ::Money.from_amount(BigDecimal(amount), currency)
            else
              raise NotImplementedError, "cast_value(value):Don't know how to cast #{value.class} #{value.inspect} into Roaringbitmap"
            end
          end

          # Support for output default values to schema.rb
          def type_cast_for_schema(value)
            serialize(value).inspect
          end

          private

          def type_cast_array(value, method)
            if value.is_a?(::Array)
              value.compact.map { |item| type_cast_array(item, method) }
            else
              serialize(value)
            end
          end
        end
      end
    end
  end
end

# Register our type in ActiveRecord
# activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb
require 'active_record/connection_adapters/postgresql_adapter'
PostgreSQLAdapterWithRoaringbitmap = Module.new do
  def initialize_type_map(m = type_map)
    m.register_type "roaringbitmap" do |*_args, _sql_type|
      ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Roaringbitmap.new
    end
    m.alias_type "_roaringbitmap", "roaringbitmap"

    # Call Rails logic after ours or it will complain that OID isn't supported
    super
  end
end
ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.prepend(PostgreSQLAdapterWithRoaringbitmap)
ActiveRecord::Type.register(:roaringbitmap, ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Roaringbitmap, adapter: :postgresql)

# Add methods for migrations DSL
module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module ColumnMethods
        def roaringbitmap(name, options = {})
          column(name, :roaringbitmap, **{ default: "'{}'::roaringbitmap" }.merge(options))
        end
      end
    end
  end
end

# activerecord/lib/active_record/connection_adapters/postgresql/schema_statements.rb
require 'active_record/connection_adapters/postgresql/schema_statements'
module SchemaStatementsWithRoaringbitmap
  def type_to_sql(type, limit: nil, precision: nil, scale: nil, array: nil, **)
    case type.to_s
    when 'roaringbitmap' then 'roaringbitmap'
    else super
    end
  end
end
ActiveRecord::ConnectionAdapters::PostgreSQL::SchemaStatements.prepend(SchemaStatementsWithRoaringbitmap)
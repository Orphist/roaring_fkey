# frozen_string_literal: true
require 'pry'
require 'roaring_fkey/postgresql/adapter/oid/roaringbitmap'
require 'roaring_fkey/postgresql/adapter/oid/roaringbitmap64'

module RoaringFkey
  module PostgreSQL
    module Arel
      module Visitors
        RoaringbitmapType = ::ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Roaringbitmap
        Roaringbitmap64Type = ::ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Roaringbitmap64

        # Enclose select manager with parenthesis
        # :TODO: Remove when checking the new version of Arel
        def visit_Arel_SelectManager(o, collector)
          collector << '('
          visit(o.ast, collector) << ')'
        end

        # Allow quoted arrays to get here
        def visit_Arel_Nodes_Quoted(o, collector)
          return super unless o.expr.is_a?(::Enumerable)
          quote_array(o.expr, collector)
        end

        # Allow quoted arrays to get here
        def visit_Arel_Nodes_Casted(o, collector)
          value = o.respond_to?(:val) ? o.val : o.value
          return super unless value.is_a?(::Enumerable)
          quote_array(value, collector)
        end

        ## RoaringFkey VISITORS
        # Allow casting any node
        def visit_RoaringFkey_PostgreSQL_Arel_Nodes_Cast(o, collector)
          visit(o.left, collector) << '::' << o.right
        end

        def visit_Arel_Nodes_HomogeneousIn(o, collector)
          return super unless o.attribute.type_caster.type.eql?(:roaringbitmap) ||
              o.attribute.type_caster.type.eql?(:roaringbitmap64)

          collector.preparable = false

          collector << quote_table_name(o.table_name) << "." << quote_column_name(o.column_name)

          build_function = build_function_for_type(o.attribute.type_caster.type)

          if o.type == :in
            collector << " && #{build_function}(ARRAY["
          else # wat?
            collector << " - #{build_function}(ARRAY["
          end

          values = o.values

          if values.empty?
            collector << @connection.quote(nil)
          else
            collector.add_binds(values, o.proc_for_binds, &bind_block)
          end

          collector << "])"
          collector
        end

        def visit_Arel_Nodes_Equality(o, collector)
          if o.right.respond_to?(:value) &&
              %i[roaringbitmap roaringbitmap64].include?(o.left.type_caster.type) &&
              [RoaringbitmapType, Roaringbitmap64Type].include?(o.right.value.type.class)
            if o.right.value.value.is_a?(Array)
              collector = visit o.left, collector
              collector << " && "
              quote_roaringbiymap(o.right.value.value, collector, o.left.type_caster.type)
            elsif o.right.value.value.is_a?(::ActiveRecord::StatementCache::Substitute)
              super
            else
              collector = visit o.left, collector
              collector << " @> "
              visit o.right.value.value, collector
            end
          else
            super
          end
        end

        def visit_Arel_Nodes_In(o, collector)
          return super unless %i[roaringbitmap roaringbitmap64].include?(o.left.type_caster.type)

          collector.preparable = false
          attr, values = o.left, o.right

          if Array === values
            unless values.empty?
              values.delete_if { |value| unboundable?(value) }
            end

            if values.empty?
              collector << " #{empty_func(o.left.type_caster.type)}("
              visit(o.left, collector) << ")"
              return collector
            end
          end

          visit(attr, collector) << " IN ("
          visit(values, collector) << ")"
        end

        def visit_Arel_Nodes_NotIn(o, collector)
          return super unless %i[roaringbitmap roaringbitmap64].include?(o.left.type_caster.type)

          collector.preparable = false
          attr, values = o.left, o.right

          if Array === values
            unless values.empty?
              values.delete_if { |value| unboundable?(value) }
            end

            if values.blank?
              collector << "NOT #{empty_func(o.left.type_caster.type)}("
              visit(o.left, collector) << ")"
              return collector
            end
          else
            collector << "NOT #{empty_func(o.left.type_caster.type)}("
            visit(o.left, collector) << ")"
            return collector
          end

          visit(attr, collector) << " NOT IN ("
          visit(values, collector) << ")"
        end

        def visit_Arel_Nodes_NotEqual(o, collector)
          left = o.left
          right = o.right
          if [RoaringbitmapType, Roaringbitmap64Type].include?(right.value.type.class) &&
              %i[roaringbitmap roaringbitmap64].include?(left.type_caster.type)
            if right.nil? || right.value.nil?
              if right.value.value
                collector << "NOT #{empty_func(right.value.value.type.class)}("
                visit(right.value.value, collector) << ")"
              else
                collector << "NOT #{empty_func(left.type_caster.type)}("
                visit(left, collector) << ")"
              end
            elsif right.is_a?(Array)
              build_function = build_function_for_type(left.type_caster.type)
              collector << "NOT("
              collector = visit(left, collector)
              collector << " @> #{build_function}(ARRAY["
              collector << right.value.value.join(',') << "]))"
            else
              collector << "NOT("
              collector = visit(left, collector)
              collector << " @> "
              collector << right.value.value.to_s << ")"
            end
          else
            super
          end
        end

        private

        def quote_array(value, collector)
          value = value.map(&::Arel::Nodes.method(:build_quoted))

          collector << 'ARRAY['
          visit_Array(value, collector)
          collector << ']'
        end

        def quote_roaringbiymap(value, collector, type = :roaringbitmap)
          value = value.map(&::Arel::Nodes.method(:build_quoted))

          build_function = build_function_for_type(type)
          collector << "#{build_function}(ARRAY['"
          visit_Array(value, collector)
          collector << '])'
        end

        def build_function_for_type(type)
          case type
          when :roaringbitmap
            'rb_build'
          when :roaringbitmap64
            'rb64_build'
          else
            raise "Unsupported type: #{type}"
          end
        end

        def empty_func(arg_type)
          if arg_type == :roaringbitmap64 || arg_type.class == Roaringbitmap64Type
            'rb64_is_empty'
          else
            'rb_is_empty'
          end
        end
      end

      ::Arel::Visitors::PostgreSQL.prepend(Visitors)
    end
  end
end

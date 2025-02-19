# frozen_string_literal: true
require 'pry'
require 'roaring_fkey/postgresql/adapter/oid/roaringbitmap'

module RoaringFkey
  module PostgreSQL
    module Arel
      module Visitors
        RoaringbitmapType = ::ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Roaringbitmap

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
          return super unless o.attribute.type_caster.type.eql?(:roaringbitmap)

          collector.preparable = false

          collector << quote_table_name(o.table_name) << "." << quote_column_name(o.column_name)

          if o.type == :in
            collector << " && rb_build(ARRAY["
          else # wat?
            collector << " - rb_build(ARRAY["
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
              o.left.type_caster.type.eql?(:roaringbitmap) &&
              o.right.value.type.is_a?(RoaringbitmapType)
            if o.right.value.value.is_a?(Array)
              collector = visit o.left, collector
              collector << " && "
              quote_roaringbiymap(o.right.value.value, collector)
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
          return super unless o.left.type_caster.type.eql?(:roaringbitmap)
          collector.preparable = false
          attr, values = o.left, o.right

          if Array === values
            unless values.empty?
              values.delete_if { |value| unboundable?(value) }
            end

            if values.empty?
              collector << " rb_is_empty("
              visit(o.left, collector) << ")"
              return collector
            end
          end

          visit(attr, collector) << " IN ("
          visit(values, collector) << ")"
        end

        def visit_Arel_Nodes_NotIn(o, collector)
          return super unless o.left.type_caster.type.eql?(:roaringbitmap)

          collector.preparable = false
          attr, values = o.left, o.right

          if Array === values
            unless values.empty?
              values.delete_if { |value| unboundable?(value) }
            end

            if values.blank?
              collector << "NOT rb_is_empty("
              visit(o.left, collector) << ")"
              return collector
            end
          else
            collector << "NOT rb_is_empty("
            visit(o.left, collector) << ")"
            return collector
          end

          visit(attr, collector) << " NOT IN ("
          visit(values, collector) << ")"
        end

        def visit_Arel_Nodes_NotEqual(o, collector)
          return super if !o.right.value.type.is_a?(RoaringbitmapType) &&
            !o.left.value.type.is_a?(RoaringbitmapType)

          right = o.right

          if right.nil? || right.value.nil?
            if right.value.value
              collector << "NOT rb_is_empty("
              visit(right.value.value, collector) << ")"
            else
              collector << "NOT rb_is_empty("
              visit(o.left, collector) << ")"
            end
          elsif right.is_a?(Array)
            collector << "NOT("
            collector = visit(o.left, collector)
            collector << " @> rb_build(ARRAY["
            collector << right.value.value.join(',') << "]))"
          else
            collector << "NOT("
            collector = visit(o.left, collector)
            collector << " @> "
            collector << right.value.value.to_s << ")"
          end
        end

        private

          def quote_array(value, collector)
            value = value.map(&::Arel::Nodes.method(:build_quoted))

            collector << 'ARRAY['
            visit_Array(value, collector)
            collector << ']'
          end

          def quote_roaringbiymap(value, collector)
            value = value.map(&::Arel::Nodes.method(:build_quoted))

            collector << 'rb_build(ARRAY['
            visit_Array(value, collector)
            collector << '])'
          end
      end

      ::Arel::Visitors::PostgreSQL.prepend(Visitors)
    end
  end
end

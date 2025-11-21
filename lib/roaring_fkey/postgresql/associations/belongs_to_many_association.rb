# frozen_string_literal: true

require 'active_record/associations/collection_association'

module RoaringFkey
  module PostgreSQL
    module Associations
      class BelongsToManyAssociation < ::ActiveRecord::Associations::CollectionAssociation
        include ::ActiveRecord::Associations::ForeignAssociation

        def ids_reader
          if loaded?
            target.pluck(reflection.association_primary_key)
          elsif !target.empty?
            load_target.pluck(reflection.association_primary_key)
          else
            stale_state || column_default_value
          end
        end

        def ids_writer(ids)
          ids = ids.presence || column_default_value
          owner.write_attribute(source_attr, ids)
          return unless owner.persisted? && owner.attribute_changed?(source_attr)

          owner.update_attribute(source_attr, ids)
        end

        def size
          if loaded?
            target.size
          elsif !target.empty?
            unsaved_records = target.select(&:new_record?)
            unsaved_records.size + stale_state.size
          else
            stale_state&.size || 0
          end
        end

        def empty?
          size.zero?
        end

        def include?(record)
          return false unless record.is_a?(reflection.klass)
          return include_in_memory?(record) if record.new_record?

          (!target.empty? && target.include?(record)) ||
            stale_state&.include?(record.read_attribute(klass_attr))
        end

        def load_target
          if stale_target? || find_target?
            new_records = PostgreSQL::AR615 ? target.extract!(&:persisted?) : []
            @target = merge_target_lists((find_target || []) + new_records, target)
          end

          loaded!
          target
        end

        def build_changes(from_target = false)
          return yield if defined?(@_building_changes) && @_building_changes

          @_building_changes = true
          yield.tap { ids_writer(from_target ? ids_reader : stale_state) }
        ensure
          @_building_changes = nil
        end

        def insert_record(record, *)
          (record.persisted? || super).tap do |saved|
            ids_rewriter(record.read_attribute(klass_attr), :<<) if saved
          end
        end

        ## BELONGS TO
        def default(&block)
          writer(owner.instance_exec(&block)) if reader.nil?
        end

        private

          def _create_record(attributes, raises = false, &block)
            if attributes.is_a?(Array)
              attributes.collect { |attr| _create_record(attr, raises, &block) }
            else
              build_record(attributes, &block).tap do |record|
                transaction do
                  result = nil
                  add_to_target(record) do
                    result = insert_record(record, true, raises) { @_was_loaded = loaded? }
                  end
                  raise ActiveRecord::Rollback unless result
                end
              end
            end
          end

          # When the idea is to nullify the association, then just set the owner
          # +primary_key+ as empty
          def delete_count(method, scope, ids)
            size_cache = scope.delete_all if method == :delete_all
            (size_cache || ids.size).tap { ids_rewriter(ids, :-) }
          end

          def delete_or_nullify_all_records(method)
            delete_count(method, scope, ids_reader)
          end

          # Deletes the records according to the <tt>:dependent</tt> option.
          def delete_records(records, method)
            ids = read_records_ids(records)
            if method == :destroy
              records.each(&:destroy!)
              ids_rewriter(ids, :-)
            else
              scope = self.scope.where(klass_attr => records)
              delete_count(method, scope, ids)
            end
          end

          def source_attr
            reflection.foreign_key
          end

          def klass_attr
            reflection.active_record_primary_key
          end

          def read_records_ids(records)
            return unless records.present?
            Array.wrap(records).each_with_object(klass_attr).map(&:read_attribute).presence
          end

          def ids_rewriter(ids, operator)
            list = owner[source_attr] ||= []
            list = list.public_send(operator, ids)
            cleaned_list = list.uniq.compact.presence || column_default_value
            owner[source_attr] = cleaned_list

            return if @_building_changes || !owner.persisted?
            owner.update_attribute(source_attr, cleaned_list)
          end

          def column_default_value
            #FixMe: owner.class.columns_hash is not with_indifferent_access but w/string keys
            # so temporary source_attr.to_s
            owner.class.columns_hash[source_attr.to_s].default
          end

          ## HAS MANY
          def replace_records(*)
            build_changes(true) { super }
          end

          def concat_records(*)
            build_changes(true) { super }
          end

          def delete_or_destroy(*)
            build_changes(true) { super }
          end

          def difference(a, b)
            a - b
          end

          def intersection(a, b)
            a & b
          end

          ## BELONGS TO
          def scope_for_create
            super.except!(klass.primary_key)
          end

          def find_target?
            !loaded? && foreign_key_present? && klass
          end

          def find_target
            if strict_loading? && owner.validation_context.nil?
              Base.strict_loading_violation!(owner: owner.class, reflection: reflection)
            end

            scope = self.scope
            return scope.to_a if skip_statement_cache?(scope)

            sc = reflection.association_scope_cache(klass, owner) do |params|
              as = AssociationScope.create { params.bind }
              target_scope.merge!(as.scope(self))
            end

            binds = AssociationScope.get_bind_values(owner, reflection.chain)
            sc.execute(binds, klass.connection) { |record| set_inverse_instance(record) }
          end

          def foreign_key_present?
            stale_state.present?
          end

          def invertible_for?(record)
            inverse = inverse_reflection_for(record)
            inverse && (inverse.has_many? && inverse.connected_through_array?)
          end

          def stale_state
            owner.read_attribute(source_attr)
          end
      end

      ::ActiveRecord::Associations.const_set(:BelongsToManyAssociation, BelongsToManyAssociation)
    end
  end
end

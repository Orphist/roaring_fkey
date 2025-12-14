# frozen_string_literal: true

module RoaringFkey
  module PostgreSQL
    module Associations
      module Preloader
        module Association

          delegate :belongs_to_many_association?, to: :@reflection

          # For reflections connected through an array, make sure to properly
          # decuple the list of ids and set them as associated with the owner
          def run
            return super unless belongs_to_many_association?
            run_array_for_belongs_to_many
          end

          private

            # Specific run for belongs_many association
            def run_array_for_belongs_to_many
              # Add reverse to has_many
              records = groupped_records
              owners.each do |owner|
                items = records.values_at(*Array.wrap(owner[owner_key_name]))
                associate_records_to_owner(owner, items.flatten)
              end
            end

            if PostgreSQL::AR604
            # This is how Rails 6.0.4 and 6.1 now load the records
              def load_records
                return super unless belongs_to_many_association?

                @records_by_owner = {}.compare_by_identity
                raw_records = owner_keys.empty? ? [] : records_for(owner_keys)

                @preloaded_records = raw_records.select do |record|
                  assignments = false

                  ids = convert_key(record[association_key_name])
                  owners_by_key.values_at(*ids).flat_map do |owner|
                    entries = (@records_by_owner[owner] ||= [])

                    if reflection.collection? || entries.empty?
                      entries << record
                      assignments = true
                    end
                  end

                  assignments
                end
              end
            end

            # Build correctly the constraint condition in order to get the
            # associated ids
            def records_for(ids, &block)
              return super unless belongs_to_many_association?
              condition = scope.arel_table[association_key_name]
              condition = reflection.build_id_constraint(condition, ids.flatten.uniq)
              scope.where(condition).load(&block)
            end

            def associate_records_to_owner(owner, records)
              return super unless belongs_to_many_association?
              association = owner.association(reflection.name)
              association.loaded!
              association.target.concat(records)
            end

            def groupped_records
              preloaded_records.group_by do |record|
                convert_key(record[association_key_name])
              end
            end
        end

        ::ActiveRecord::Associations::Preloader::Association.prepend(Association)
      end
    end
  end
end

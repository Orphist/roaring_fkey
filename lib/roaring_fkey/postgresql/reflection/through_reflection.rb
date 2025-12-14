# frozen_string_literal: true

module RoaringFkey
  module PostgreSQL
    module Reflection
      module ThroughReflection
        delegate :build_id_constraint, :belongs_to_many_association?, to: :source_reflection
      end

      ::ActiveRecord::Reflection::ThroughReflection.include(ThroughReflection)
    end
  end
end

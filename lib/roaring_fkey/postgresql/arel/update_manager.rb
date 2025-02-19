# frozen_string_literal: true

module RoaringFkey
  module PostgreSQL
    module Arel
      module UpdateManager

        def only
          @ctx.source.only = true
        end

      end

      ::Arel::SelectManager.include SelectManager
    end
  end
end

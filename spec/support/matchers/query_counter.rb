module Rspec
  module QueryCountLimiter
    module ActiveRecord
      class QueryCounter
        attr_reader :query_count

        def initialize
          @query_count = 0
        end

        def to_proc
          ->(*args) { callback(*args) }
        end

        def callback(_name, _start, _finish, _message_id, values)
          # puts values
          @query_count += 1 unless %w[CACHE SCHEMA].include?(values[:name])
        end
      end
    end
  end
end

# frozen_string_literal: true

# Helpers for SQL functions testing
module RoaringFkey
  module SqlHelpers
    # Perform SQL query and return the results
    def sql(query)
      result = ::ActiveRecord::Base.connection.execute query
      result.values.first&.first
    end
  end
end

RSpec.configure do |config|
  config.include RoaringFkey::SqlHelpers, type: :sql
end

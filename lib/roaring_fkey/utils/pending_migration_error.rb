# frozen_string_literal: true

require "rails/generators"

module RoaringFkey
  module Utils
    class PendingMigrationError < StandardError
      if Rails::VERSION::MAJOR >= 6
        require "active_record"
        require "active_support/actionable_error"
        include ActiveSupport::ActionableError

        action "Upgrade RoaringFkey" do
          Rails::Generators.invoke("roaring_fkey:install", ["--update"])
          ActiveRecord::Tasks::DatabaseTasks.migrate
          if ActiveRecord::Base.dump_schema_after_migration
            ActiveRecord::Tasks::DatabaseTasks.dump_schema(
              ActiveRecord::Base.connection_db_config
            )
          end
        end
      end
    end
  end
end

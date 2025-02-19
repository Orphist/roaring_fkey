# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"
require "roaring_fkey/utils/function_definitions"
require_relative "../inject_sql"
require 'roaring_fkey/version'

module RoaringFkey
  module Generators
    class InstallGenerator < ::Rails::Generators::Base # :nodoc:
      include Rails::Generators::Migration
      include InjectSql

      source_root File.expand_path("templates", __dir__)
      source_paths << File.expand_path("functions", __dir__)

      class_option :update, type: :boolean, optional: true,
        desc: "Define whether this is an update migration"

      def generate_roaringbitmap_migration
        return if update? || installed_recent_version?

        migration_template "roaringbitmap.rb.erb", "db/migrate/enable_roaringbitmap.rb"
      end

      def generate_migration
        return if installed_recent_version?

        migration_template "migration.rb.erb", "db/migrate/#{migration_name}.rb"
      end

      no_tasks do
        def migration_name
          if update?
            "roaring_fkey_update_#{::RoaringFkey::VERSION.delete(".")}"
          else
            "roaring_fkey_install"
          end
        end

        def migration_class_name
          migration_name.classify
        end

        def update?
           options[:update]
        end

        def previous_version_for(name)
          all_functions.filter_map { |path| Regexp.last_match[1].to_i if path =~ %r{#{name}_v(\d+).sql} }.max
        end

        def all_functions
          @all_functions ||=
            begin
              res = nil
              in_root do
                res = if File.directory?("db/functions")
                  Dir.entries("db/functions")
                else
                  []
                end
              end
              res
            end
        end

        def function_definitions
          @function_definitions ||= ::RoaringFkey::Utils::FunctionDefinitions.from_fs
        end

        def roaring_fkey_version
          ::RoaringFkey::VERSION.delete(".")
        end

        def functions_version
          ::ActiveRecord::Base.connection.select_value(
            <<-SQL
              SELECT roaring_fkey_version();
            SQL
          )
        rescue
          return 0
        end

        def obsolete_version?
          return true if functions_version.zero?

          functions_version < roaring_fkey_version.to_i
        end

        def installed_recent_version?
          !obsolete_version?
        end
      end

      def self.next_migration_number(dir)
        ::ActiveRecord::Generators::Base.next_migration_number(dir)
      end
    end
  end
end

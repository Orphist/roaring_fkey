# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record/migration/migration_generator"
require_relative "../inject_sql"

module RoaringFkey
  module Generators
    class ModelGenerator < ::ActiveRecord::Generators::Base # :nodoc:
      include InjectSql

      source_root File.expand_path("templates", __dir__)

      argument :attributes,
               type: :array,
               default: [],
               banner: "field:references"

      class_option :path, type: :string, optional: true, desc: "Specify path to the model file"
      class_option :name, type: :string, optional: true, desc: "Migration name"

      def generate_migration
        if reference_name.blank?
          warn "Use mandatory arg: field_name:references"
          exit(1)
        end

        migration_template "migration.rb.erb", "db/migrate/#{migration_name}.rb"
      end

      def inject_roaring_fkey_to_model
        indents = "  " * (class_name.scan("::").count + 1)
        code_snippet = "#{indents}belongs_to_many :#{reference_name.pluralize}, anonymous_class: #{reference_name.classify}, foreign_key: :#{fkey}, inverse_of: false\n"
        inject_into_class(model_file_path, class_name.demodulize, code_snippet)
      end

      no_tasks do
        def migration_name
          return options[:name] if options[:name].present?

          "add_roaring_fkey_#{fkey}_to_#{plural_table_name}"
        end

        def full_table_name
          config = ActiveRecord::Base
          "#{config.table_name_prefix}#{table_name}#{config.table_name_suffix}"
        end

        def reference_name
          attributes.select(&:reference?)&.first&.name
        end

        def fkey
          reference_name + "_ids"
        end

        # def precision
        #   options[:precision]
        # end
      end

      private

      def model_file_path
        options[:path] || File.join("app", "models", "#{file_path}.rb")
      end
    end
  end
end

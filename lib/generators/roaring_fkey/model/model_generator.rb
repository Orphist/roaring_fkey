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
      class_option :type, type: :string, default: 'roaringbitmap64', desc: "Bitmap type: roaringbitmap64 by default, or roaringbitmap when fkey:int type"

      def initialize(args, *options) # :nodoc:
        # Extract type option from args if present (format: type:roaringbitmap)
        type_arg = args.find { |arg| arg.match?(/\Atype:(roaringbitmap|roaringbitmap64)\z/) }
        @extracted_type_from_initialize = nil
        if type_arg
          # Remove from args and store the extracted type
          args.delete(type_arg)
          @extracted_type_from_initialize = type_arg.split(':', 2)[1]
        end
        
        # Create a modified options hash to pass to super with the extracted type taking precedence
        if @extracted_type_from_initialize
          # The last element in options is typically the options hash
          if options.last.is_a?(Hash)
            options.last[:type] = @extracted_type_from_initialize
          else
            # If there's no options hash, add one with the type
            options << { type: @extracted_type_from_initialize }
          end
        end
        
        super
      end

      def generate_migration
        $stdout.puts ["4- -   --    attributes:", attributes]
        $stdout.puts ["4- -   --    path:", options[:path]]
        $stdout.puts ["4- -   --    name:", options[:name]]
        $stdout.puts ["4- -   --    type:", options[:type]]
        attributes.each do |attribute|
          if attribute.reference?
            if reference_name.blank?
              warn "Use mandatory arg: field_name:references"
              exit(1)
            end
          else
            $stdout.puts ["4- -   --  1 attribute: non-reference, ", attribute]
          end
        end

        @table_name = table_name
        @reference_name = reference_name
        @fkey = fkey
        @migration_class_name = migration_name.camelize

        migration_template "migration.rb.erb", "db/migrate/#{migration_name}.rb"
      end

      def reference_type
        @extracted_type_from_initialize || options[:type]
      end

      def type_default_value
        roaringbitmap64? ? "'{}'::roaringbitmap64" : "'{}'::roaringbitmap"
      end

      def roaringbitmap64?
        reference_type == 'roaringbitmap64'
      end

      def inject_roaring_fkey_to_model
        indents = "  " * (class_name.scan("::").count + 1)
        bitmap_type = options[:type]
        code_snippet = "#{indents}belongs_to_many :#{reference_name.pluralize}, anonymous_class: #{reference_name.classify}, foreign_key: :#{fkey}, inverse_of: false, type: :#{bitmap_type}\n"
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
      end

      private

      def model_file_path
        options[:path] || File.join("app", "models", "#{file_path}.rb")
      end
    end
  end
end

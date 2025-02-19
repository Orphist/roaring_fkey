# frozen_string_literal: true

module RoaringFkey
  module PostgreSQL
    include ActiveSupport::Configurable

    # Stores a version check for compatibility purposes
    AR604 = (ActiveRecord.gem_version >= Gem::Version.new('6.0.4'))
    AR610 = (ActiveRecord.gem_version >= Gem::Version.new('6.1.0'))
    AR615 = (ActiveRecord.gem_version >= Gem::Version.new('6.1.5'))

    # Use the same logger as the Active Record one
    def self.logger
      ActiveRecord::Base.logger
    end

    # Allow nested configurations
    # :TODO: Rely on +inheritable_copy+ to make nested configurations
    config.define_singleton_method(:nested) do |name, &block|
      klass = Class.new(ActiveSupport::Configurable::Configuration).new
      block.call(klass) if block
      send("#{name}=", klass)
    end

    # Set if any information that requires querying and searching or collectiong
    # information shuld be eager loaded. This automatically changes when rails
    # same configuration is set to true
    config.eager_load = false

    # This allows default values to have extended values like arrays and casted
    # values. Extended defaults are still experimental, so enable and test it
    # before using it in prod
    config.use_extended_defaults = false

    # Set a list of irregular model name when associated with table names
    config.irregular_models = {}
    def config.irregular_models=(hash)
      PostgreSQL.config[:irregular_models] = hash.map do |(table, model)|
        [table.to_s, model.to_s]
      end.to_h
    end

    # Configure associations features
    config.nested(:associations) do |assoc|

      # Define if +belongs_to_many+ associations are marked as required by
      # default. False means that no validation will be performed
      assoc.belongs_to_many_required_by_default = false
    end
  end
end

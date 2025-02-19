# frozen_string_literal: true

module RoaringFkey
  module PostgreSQL
    # = RoaringFkey PostgreSQL Railtie
    class Railtie < Rails::Railtie # :nodoc:

      # Get information from the running rails app
      initializer 'roaring-fkey-postgresql' do |app|
        roaring_pg_config = RoaringFkey::PostgreSQL.config
        roaring_pg_config.eager_load = app.config.eager_load

        # Setup belongs_to_many association
        ActiveRecord::Base.belongs_to_many_required_by_default =
          roaring_pg_config.associations.belongs_to_many_required_by_default
      end
    end
  end
end

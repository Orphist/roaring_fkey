require 'i18n'
require 'ostruct'
require 'active_model'
require 'active_record'
require 'active_support'

require 'active_support/core_ext/date/acts_like'
require 'active_support/core_ext/time/zones'
require 'active_record/connection_adapters/postgresql_adapter'

require 'roaring_fkey/postgresql/config'
require 'roaring_fkey/postgresql/arel'
require 'roaring_fkey/postgresql/adapter'
require 'roaring_fkey/postgresql/associations'
require 'roaring_fkey/postgresql/attributes'
require 'roaring_fkey/postgresql/autosave_association'
require 'roaring_fkey/postgresql/base'
require 'roaring_fkey/postgresql/reflection'
require 'roaring_fkey/postgresql/table_name'

require 'roaring_fkey/postgresql/railtie' if defined?(Rails)

module RoaringFkey
  module PostgreSQL
  end
end

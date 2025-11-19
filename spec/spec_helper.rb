# frozen_string_literal: true

require 'roaring_fkey'
require 'factory_bot'
require 'dotenv'
require 'faker'
require 'rspec'
require 'byebug'
require 'pg'
require 'tracer'
require 'pry'
require 'fileutils'
require "rails/generators"
require "rails/generators/test_case"

Dotenv.load

ENV["RAILS_ENV"] = "test"

begin
  connection_options = {adapter: "postgresql",
                        database: "roaring_fkey_test",
                        min_messages: "warning",
                        prepared_statements: false,
                        port: ENV["DB_PORT"]}
  opts = { url: ENV['DATABASE_URL'] }.compact_blank || connection_options
  puts opts: opts
  ActiveRecord::Base.establish_connection(opts)
  connection = ActiveRecord::Base.connection
  connection.execute("SELECT 1")
rescue ActiveRecord::NoDatabaseError => e
  at_exit do
    puts "-" * 80
    puts "Unable to connect to database.  Please run:"
    puts
    puts "    createdb roaring_fkey_test"
    puts "-" * 80
  end
  raise e
end

load File.join('schema.rb')

Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].sort.each { |f| require f }
Dir.glob(File.join('spec', 'roaring_fkey', '{models,factories,mocks}', '**', '*.rb')) do |file|
  require file[5..-4]
end

require "acceptance_helper"

I18n.load_path << Pathname.pwd.join('spec', 'roaring_fkey', 'en.yml')

ActiveRecord::Base.logger = Logger.new(STDOUT)
ActiveRecord::Base.logger.level = Logger::DEBUG

RSpec.configure do |config|
  config.extend Mocks::CreateTable
  config.include Mocks::CacheQuery
  config.include FactoryBot::Syntax::Methods
  config.include FileUtils
  config.include Rails::Generators::Testing::Behaviour

  config.formatter = :documentation
  config.color     = true
  config.tty       = true

  # Handles acton before rspec initialize
  config.before(:suite) do |example|
    ActiveSupport::Deprecation.silenced = true
    example.metadata[:aggregate_failures] = true
  end

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups

  # config.filter_run_when_matching :focus
  # config.example_status_persistence_file_path = "spec/examples.txt"
  # if config.files_to_run.one?
  #   # Use the documentation formatter for detailed output,
  #   # unless a formatter has already been configured
  #   # (e.g. via a command-line flag).
  #   config.default_formatter = "doc"
  # end
  # config.profile_examples = 10

  config.order = :random
  Kernel.srand config.seed

  config.before(:each, :db) do
    ActiveRecord::Base.connection.begin_transaction(joinable: false)
  end

  config.append_after(:each, :db) do |ex|
    ActiveRecord::Base.connection.rollback_transaction

    raise "Migrations are pending: #{ex.metadata[:location]}" if ActiveRecord::Base.connection.migration_context.needs_migration?
  end
  config.backtrace_exclusion_patterns = [
    %r{spec/support},
    %r{bin/rspec},
    %r{bin/ruby},
    %r{gems/raven},
    %r{gems/rspec},
    %r{gems/rack},
   # %r{gems/railties},
    %r{gems/rspec-core},
   #%r{gems/acti},
    /rspec-core/,
    %r{gems/rspec-core},
    %r{gems/pry},
    %r{gems/factory}
  ]
end

RSpec::Matchers.define_negated_matcher :not_change, :change

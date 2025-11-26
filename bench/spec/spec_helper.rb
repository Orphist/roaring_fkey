# frozen_string_literal: true

require_relative '../lib/tpch/data_generator'
require_relative '../lib/tpch/random_generator'
require_relative '../lib/tpch/scale_calculator'
require_relative '../lib/tpch/file_writer'
require_relative '../lib/tpch/text_pools'

Dir[File.join(__dir__, '../lib/tpch/generators/*.rb')].each { |f| require f }

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = "spec/.rspec_status"
  config.disable_monkey_patching!
  config.warnings = true
  config.order = :random

  Kernel.srand config.seed
end

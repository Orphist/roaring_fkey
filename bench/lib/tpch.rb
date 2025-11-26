# frozen_string_literal: true

require_relative 'tpch/data_generator'
require_relative 'tpch/random_generator'
require_relative 'tpch/scale_calculator'
require_relative 'tpch/file_writer'
require_relative 'tpch/text_pools'

# Require all generators
Dir[File.join(__dir__, 'tpch', 'generators', '*.rb')].each do |file|
  require file
end

module Tpch
  # Main module for TPC-H data generation
end
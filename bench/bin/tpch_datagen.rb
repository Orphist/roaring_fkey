#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/tpch'

# Parse CLI args: -s scale, -C parallel_count, -S segment_id, -o output_dir
# Example: bin/tpch_datagen.rb -s 1 -C 4 -S 1 -o ./generated

require 'optparse'

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: #{$0} [options]"

  opts.on("-s", "--scale SCALE", Float, "Scale factor (default: 1)") do |s|
    options[:scale] = s
  end

  opts.on("-C", "--parallel COUNT", Integer, "Number of parallel segments (default: 1)") do |c|
    options[:parallel_count] = c
  end

  opts.on("-S", "--segment ID", Integer, "Segment ID (1-based, default: 1)") do |s|
    options[:segment_id] = s
  end

  opts.on("-o", "--output DIR", String, "Output directory (default: ./generated)") do |o|
    options[:output_dir] = o
  end

  opts.on("-v", "--verbose", "Verbose output") do |v|
    options[:verbose] = v
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end.parse!

# Set defaults
options[:scale] ||= 1.0
options[:parallel_count] ||= 1
options[:segment_id] ||= 1
options[:output_dir] ||= './generated'

# Validate inputs
if options[:scale] <= 0
  puts "Error: Scale factor must be positive"
  exit 1
end

if options[:parallel_count] < 1
  puts "Error: Parallel count must be at least 1"
  exit 1
end

if options[:segment_id] < 1 || options[:segment_id] > options[:parallel_count]
  puts "Error: Segment ID must be between 1 and #{options[:parallel_count]}"
  exit 1
end

# Create output directory if it doesn't exist
require 'fileutils'
FileUtils.mkdir_p(options[:output_dir])

# Invoke main generator orchestrator
generator = Tpch::DataGenerator.new(
  scale: options[:scale],
  parallel_count: options[:parallel_count],
  segment_id: options[:segment_id],
  output_dir: options[:output_dir],
  verbose: options[:verbose]
)

generator.generate

puts "TPC-H data generation completed successfully!" if options[:verbose]
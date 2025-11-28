#!/usr/bin/env ruby
# frozen_string_literal: true

require 'optparse'
require_relative '../lib/tpch/data_generator'

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: tpch_datagen.rb [options]"

  opts.on("-s SCALE", "--scale SCALE", Float, "Scale factor (default: 1.0)") do |s|
    options[:scale] = s
  end

  opts.on("-C COUNT", "--count COUNT", Integer, "Total number of parallel segments (default: 1)") do |c|
    options[:count] = c
  end

  opts.on("-S SEGMENT", "--segment SEGMENT", Integer, "Segment number (1 to COUNT, default: 1)") do |s|
    options[:segment] = s
  end

  opts.on("-o OUTPUT", "--output OUTPUT", String, "Output directory (default: ./generated)") do |o|
    options[:output] = o
  end

  opts.on("-v", "--verbose", "Run verbosely") do |v|
    options[:verbose] = v
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end.parse!

# Set defaults
options[:scale] ||= 1.0
options[:count] ||= 1
options[:segment] ||= 1
options[:output] ||= './generated'

# Validate inputs
if options[:segment] < 1 || options[:segment] > options[:count]
  puts "Error: segment must be between 1 and #{options[:count]}"
  exit 1
end

puts "Generating TPC-H data with scale factor #{options[:scale]}, segment #{options[:segment]}/#{options[:count]}" if options[:verbose]

generator = Tpch::DataGenerator.new(
  scale: options[:scale],
  output_dir: options[:output],
  segment: options[:segment],
  total_segments: options[:count]
)

generator.generate

puts "Data generation complete. Files written to #{options[:output]}" if options[:verbose]
# frozen_string_literal: true

require_relative 'random_generator'
require_relative 'file_writer'
require_relative 'scale_calculator'

module Tpch
  # Main orchestrator controlling generation flow
  class DataGenerator
    GENERATION_ORDER = %i[region nation customer supplier part partsupp orders lineitem].freeze

    def initialize(scale:, parallel_count:, segment_id:, output_dir:, verbose: false)
      @scale = scale
      @parallel_count = parallel_count
      @segment_id = segment_id
      @output_dir = output_dir
      @verbose = verbose

      # Initialize random_gen with deterministic seed
      base_seed = (@scale * 1_000_000) + @segment_id
      @random_gen = RandomGenerator.new(seed: base_seed)
    end

    def generate
      puts "Generating TPC-H data (scale: #{@scale}, segment: #{@segment_id}/#{@parallel_count})" if @verbose

      GENERATION_ORDER.each do |table_name|
        generate_table(table_name)
      end

      puts "Generation complete!" if @verbose
    end

    private

    def generate_table(table_name)
      puts "Generating #{table_name}..." if @verbose

      generator_class = generator_class_for(table_name)
      row_count = ScaleCalculator.row_count(table_name, @scale, @parallel_count, @segment_id)

      generator = generator_class.new(
        scale: @scale,
        segment: @segment_id,
        total_segments: @parallel_count,
        random_gen: @random_gen
      )

      writer = FileWriter.new(
        output_dir: @output_dir,
        table_name: table_name.to_s,
        segment: @segment_id
      )

      if generator.respond_to?(:generate_in_chunks)
        generator.generate_in_chunks(writer.file_path)
        puts "  Generated data for #{table_name}" if @verbose
      else
        rows = generator.generate
        writer.write_rows(rows)
        puts "  Generated #{rows.size} rows for #{table_name}" if @verbose
      end
    end

    def generator_class_for(table_name)
      class_name = "#{table_name.to_s.capitalize}Generator"
      Tpch::Generators.const_get(class_name)
    end
  end
end
# frozen_string_literal: true

require_relative '../random_generator'
require_relative '../text_pools'
require_relative '../scale_calculator'

module Tpch
  module Generators
    class PartsuppGenerator
      def initialize(scale:, segment:, total_segments:, random_gen:)
        @scale = scale
        @segment = segment
        @total_segments = total_segments
        @random_gen = random_gen
      end

      def generate
        total_parts = ScaleCalculator.row_count(:part, @scale, @total_segments, @segment)
        part_start_id = calculate_part_start_id
        total_suppliers = (10_000 * @scale).to_i
        
        rows = []
        (0...total_parts).each do |i|
          partkey = part_start_id + i
          
          4.times do |j|
            suppkey = select_supplier(partkey, j, total_suppliers)
            
            rows << {
              partkey: partkey,
              suppkey: suppkey,
              availqty: @random_gen.rand_int(1, 9999),
              supplycost: generate_supply_cost,
              comment: generate_comment
            }
          end
        end
        
        rows
      end

      private

      def calculate_part_start_id
        return 1 if @total_segments == 1
        
        total_parts = (200_000 * @scale).to_i
        rows_per_segment = total_parts / @total_segments
        
        (@segment - 1) * rows_per_segment + 1
      end

      def select_supplier(partkey, position, total_suppliers)
        ((partkey + position * 1000) % total_suppliers) + 1
      end

      def generate_supply_cost
        require 'bigdecimal'
        value = @random_gen.rand_int(100, 100_000) / 100.0
        BigDecimal(value.to_s).round(2)
      end

      def generate_comment
        length = @random_gen.rand_int(25, 100)
        syllables = TextPools::SYLLABLES
        
        (0...length).map { syllables[@random_gen.rand_int(0, syllables.length - 1)] }.join
      end
    end
  end
end

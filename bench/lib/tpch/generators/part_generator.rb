# frozen_string_literal: true

require_relative '../random_generator'
require_relative '../text_pools'
require_relative '../scale_calculator'

module Tpch
  module Generators
    class PartGenerator
      PART_TYPES = %w[STANDARD SMALL MEDIUM LARGE ECONOMY PROMO].freeze
      PART_MATERIALS = %w[TIN NICKEL BRASS STEEL COPPER].freeze
      PART_FINISHES = %w[BRUSHED BURNISHED PLATED POLISHED ANODIZED].freeze

      def initialize(scale:, segment:, total_segments:, random_gen:)
        @scale = scale
        @segment = segment
        @total_segments = total_segments
        @random_gen = random_gen
      end

      def generate
        total_rows = ScaleCalculator.row_count(:part, @scale, @total_segments, @segment)
        start_id = calculate_start_id
        
        (0...total_rows).map do |i|
          partkey = start_id + i
          
          {
            partkey: partkey,
            name: generate_part_name,
            mfgr: format("Manufacturer#%d", @random_gen.rand_int(1, 5)),
            brand: format("Brand#%d", @random_gen.rand_int(10, 55)),
            type: generate_part_type,
            size: @random_gen.rand_int(1, 50),
            container: TextPools::CONTAINER_TYPES[@random_gen.rand_int(0, TextPools::CONTAINER_TYPES.length - 1)],
            retailprice: generate_retail_price(partkey),
            comment: generate_comment
          }
        end
      end

      private

      def calculate_start_id
        return 1 if @total_segments == 1
        
        total_parts = (200_000 * @scale).to_i
        rows_per_segment = total_parts / @total_segments
        
        (@segment - 1) * rows_per_segment + 1
      end

      def generate_part_name
        syllables = TextPools::SYLLABLES
        (0...5).map { syllables[@random_gen.rand_int(0, syllables.length - 1)] }.join(' ')
      end

      def generate_part_type
        type = PART_TYPES[@random_gen.rand_int(0, PART_TYPES.length - 1)]
        finish = PART_FINISHES[@random_gen.rand_int(0, PART_FINISHES.length - 1)]
        material = PART_MATERIALS[@random_gen.rand_int(0, PART_MATERIALS.length - 1)]
        
        "#{type} #{finish} #{material}"
      end

      def generate_retail_price(partkey)
        require 'bigdecimal'
        base_price = 900 + (partkey % 200_000)
        variance = @random_gen.rand_int(-10, 10) / 100.0
        price = base_price * (1 + variance)
        
        BigDecimal(price.to_s).round(2)
      end

      def generate_comment
        length = @random_gen.rand_int(10, 30)
        syllables = TextPools::SYLLABLES
        
        (0...length).map { syllables[@random_gen.rand_int(0, syllables.length - 1)] }.join
      end
    end
  end
end

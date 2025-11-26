# frozen_string_literal: true

require_relative '../random_generator'
require_relative '../text_pools'
require_relative '../scale_calculator'

module Tpch
  module Generators
    class SupplierGenerator
      def initialize(scale:, segment:, total_segments:, random_gen:)
        @scale = scale
        @segment = segment
        @total_segments = total_segments
        @random_gen = random_gen
      end

      def generate
        total_rows = ScaleCalculator.row_count(:supplier, @scale, @total_segments, @segment)
        start_id = calculate_start_id
        
        (0...total_rows).map do |i|
          suppkey = start_id + i
          nationkey = @random_gen.rand_int(0, 24)
          
          {
            suppkey: suppkey,
            name: format("Supplier#%09d", suppkey),
            address: generate_address,
            nationkey: nationkey,
            phone: generate_phone(nationkey),
            acctbal: generate_acctbal,
            comment: generate_comment
          }
        end
      end

      private

      def calculate_start_id
        return 1 if @total_segments == 1
        
        total_suppliers = (10_000 * @scale).to_i
        rows_per_segment = total_suppliers / @total_segments
        
        (@segment - 1) * rows_per_segment + 1
      end

      def generate_address
        length = @random_gen.rand_int(10, 40)
        syllables = TextPools::SYLLABLES
        
        (0...length).map { syllables[@random_gen.rand_int(0, syllables.length - 1)] }.join
      end

      def generate_phone(nationkey)
        format("%02d-%03d-%03d-%04d", 
               nationkey + 10,
               @random_gen.rand_int(100, 999),
               @random_gen.rand_int(100, 999),
               @random_gen.rand_int(1000, 9999))
      end

      def generate_acctbal
        require 'bigdecimal'
        value = @random_gen.rand_int(-99999, 999999) / 100.0
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

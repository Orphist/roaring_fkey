# frozen_string_literal: true

require_relative '../random_generator'
require_relative '../text_pools'

module Tpch
  module Generators
    class RegionGenerator
      REGIONS = [
        [0, 'AFRICA'],
        [1, 'AMERICA'],
        [2, 'ASIA'],
        [3, 'EUROPE'],
        [4, 'MIDDLE EAST']
      ].freeze

      def initialize(scale:, segment:, total_segments:, random_gen:)
        @scale = scale
        @segment = segment
        @total_segments = total_segments
        @random_gen = random_gen
      end

      def generate
        REGIONS.map do |region_key, name|
          {
            regionkey: region_key,
            name: name,
            comment: @random_gen.rand_string(Tpch::TextPools::SYLLABLES) # Simplified comment for now
          }
        end
      end
    end
  end
end
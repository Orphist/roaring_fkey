# frozen_string_literal: true

module Tpch
  module ScaleCalculator
    BASE_ROW_COUNTS = {
      nation: 25,
      region: 5,
      customer: 150_000,
      supplier: 10_000,
      part: 200_000,
      partsupp: 800_000,
      orders: 1_500_000,
      lineitem: 6_000_000 # Approximate, depends on orders
    }.freeze

    def self.row_count(table_name, scale_factor, total_segments, segment_id)
      base_count = BASE_ROW_COUNTS.fetch(table_name)

      return base_count if %i[nation region].include?(table_name)

      total_rows = (base_count * scale_factor).to_i

      return total_rows if total_segments == 1

      rows_per_segment = total_rows / total_segments
      remainder = total_rows % total_segments

      count = rows_per_segment
      count += 1 if segment_id <= remainder
      count
    end
  end
end
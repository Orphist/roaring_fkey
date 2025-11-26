# frozen_string_literal: true

module Tpch
  class RandomGenerator
    # Linear Congruential Generator constants matching TPC-H dbgen
    A = 16807
    M = 2_147_483_647
    Q = M / A
    R = M % A

    def initialize(seed:)
      @seed = seed % M
      @seed = M - 1 if @seed == 0
    end

    def rand_int(min, max)
      # LCG implementation
      hi = @seed / Q
      lo = @seed % Q
      test = A * lo - R * hi
      @seed = test > 0 ? test : test + M

      # Scale to range
      min + (@seed % (max - min + 1))
    end

    def rand_string(pattern)
      # Handle patterns like "Customer#%09d"
      if pattern.include?('%')
        pattern % rand_int(1, 999_999_999)
      else
        # For simple text pools, select random element
        pattern[rand_int(0, pattern.length - 1)]
      end
    end

    def rand_date(start_date, end_date)
      days = (end_date - start_date).to_i
      start_date + rand_int(0, days)
    end
  end
end
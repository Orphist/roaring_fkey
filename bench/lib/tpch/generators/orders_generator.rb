# frozen_string_literal: true

require 'date'
require 'etc'
require_relative '../random_generator'
require_relative '../text_pools'
require_relative '../scale_calculator'

module Tpch
  module Generators
    class OrdersGenerator
      START_DATE = Date.new(1992, 1, 1).freeze
      END_DATE = Date.new(1998, 12, 31).freeze
      CHUNK_SIZE = 50_000
      SEEDS_FACTOR = 1_000_000
      CUSTOMERS_FACTOR = 150_000
      ORDERS_FACTOR = 1_500_000

      def initialize(scale:, segment:, total_segments:, random_gen:)
        @scale = scale
        @segment = segment
        @total_segments = total_segments
        @random_gen = random_gen
      end

      def generate_in_chunks(file_path)
        worker_count = 4
        
        total_rows = ScaleCalculator.row_count(:orders, @scale, @total_segments, @segment)
        start_id = calculate_start_id
        total_customers = (CUSTOMERS_FACTOR * @scale).to_i
        base_seed = (@scale * SEEDS_FACTOR).to_i + @segment

        # Writer Ractor
        writer = Ractor.new(file_path) do |path|
          File.open(path, 'w') do |f|
            loop do
              msg = Ractor.receive
              break if msg == :done
              f.puts(msg)
            end
          end
        end

        # Worker Ractors
        workers = worker_count.times.map do |i|
          rows_per_worker = (total_rows + worker_count - 1) / worker_count
          w_start_index = i * rows_per_worker
          w_end_index = [w_start_index + rows_per_worker, total_rows].min
          
          # Skip if this worker has no rows (e.g. small scale)
          next if w_start_index >= total_rows

          worker_seed = base_seed + i
          
          Ractor.new(writer, w_start_index, w_end_index, start_id, worker_seed, total_customers, @scale) do |w, s_idx, e_idx, global_start_id, seed, tot_cust, scale|
            rng = Tpch::RandomGenerator.new(seed: seed)
            
            # Helper for formatting
            format_val = ->(v) { v.nil? ? '' : v.to_s }

            (s_idx...e_idx).each do |offset|
              orderkey = global_start_id + offset
              orderdate = rng.rand_date(START_DATE, END_DATE)
              
              # Logic from select_order_status
              days_since = (Date.today - orderdate).to_i
              orderstatus = if days_since > 2000
                              'F'
                            elsif days_since > 365
                              rng.rand_int(0, 1) == 0 ? 'F' : 'O'
                            else
                              'O'
                            end

              # Logic from generate_comment
              comment_len = rng.rand_int(20, 80)
              comment = (0...comment_len).map { Tpch::TextPools::SYLLABLES[rng.rand_int(0, Tpch::TextPools::SYLLABLES.length - 1)] }.join

              row = [
                orderkey,
                rng.rand_int(1, tot_cust), # custkey
                orderstatus,
                '0.00', # totalprice (BigDecimal('0.00').to_s is '0.0') but usually TPC-H expects formatted. Keeping simple string for now as per original
                orderdate,
                Tpch::TextPools::ORDERPRIORITIES[rng.rand_int(0, Tpch::TextPools::ORDERPRIORITIES.length - 1)],
                format("Clerk#%09d", rng.rand_int(1, 1000)),
                0, # shippriority
                comment
              ]
              
              # Format as pipe-delimited string
              line = row.map(&format_val).join('|') + '|'
              w.send(line)
            end
          end
        end.compact

        # Wait for workers
        workers.each(&:take)
        
        # Signal writer
        writer.send(:done)
        writer.take
      end

      private

      def calculate_start_id
        return 1 if @total_segments == 1
        
        total_orders = (ORDERS_FACTOR * @scale).to_i
        rows_per_segment = total_orders / @total_segments
        
        (@segment - 1) * rows_per_segment + 1
      end

    end
  end
end

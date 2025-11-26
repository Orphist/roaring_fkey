# frozen_string_literal: true

require 'date'
require 'bigdecimal'
require_relative '../random_generator'
require_relative '../text_pools'
require_relative '../scale_calculator'

module Tpch
  module Generators
    class LineitemGenerator
      START_DATE = Date.new(1992, 1, 1).freeze
      CHUNK_SIZE = 2_000 # Lines per chunk to send to writer
      SEEDS_FACTOR = 1_000_000
      PARTS_FACTOR = 200_000
      SUPPLIERS_FACTOR = 10_000
      ORDERS_FACTOR = 1_500_000

      def initialize(scale:, segment:, total_segments:, random_gen: nil)
        @scale = scale
        @segment = segment
        @total_segments = total_segments
        @random_gen = random_gen
      end

      def generate_in_chunks(file_path, worker_count = 4)
        total_orders = ScaleCalculator.row_count(:orders, @scale, @total_segments, @segment)
        order_start_id = calculate_order_start_id
        total_parts = (PARTS_FACTOR * @scale).to_i
        total_suppliers = (SUPPLIERS_FACTOR * @scale).to_i
        base_seed = (@scale * SEEDS_FACTOR).to_i + @segment

        writer = Ractor.new(file_path) do |path|
          File.open(path, 'w') do |f|
            loop do
              msg = Ractor.receive
              break if msg == :done
              f.puts(msg)
            end
          end
        end

        workers = worker_count.times.map do |i|
          orders_per_worker = (total_orders + worker_count - 1) / worker_count
          w_start_index = i * orders_per_worker
          w_end_index = [w_start_index + orders_per_worker, total_orders].min
          
          next if w_start_index >= total_orders

          worker_seed = base_seed + i
          
          Ractor.new(writer, w_start_index, w_end_index, order_start_id, worker_seed, total_parts, total_suppliers) do |w, s_idx, e_idx, global_start_id, seed, tot_parts, tot_supp|
            rng = Tpch::RandomGenerator.new(seed: seed)

            format_val = ->(v) { v.nil? ? '' : v.to_s }
            
            buffer = []

            (s_idx...e_idx).each do |offset|
              orderkey = global_start_id + offset

              orderdate = START_DATE + rng.rand_int(0, 2556)

              rand_val = rng.rand_int(1, 100)
              num_lineitems = case rand_val
                              when 1..10 then 1
                              when 11..30 then 2
                              when 31..50 then 3
                              when 51..75 then 4
                              when 76..90 then 5
                              when 91..97 then 6
                              else 7
                              end

              (1..num_lineitems).each do |linenumber|
                partkey = rng.rand_int(1, tot_parts)

                supplier_offset = rng.rand_int(0, 3)
                suppkey = ((partkey + supplier_offset * 1_000) % tot_supp) + 1
                
                quantity = rng.rand_int(1, 50)
                shipdate = orderdate + rng.rand_int(1, 121)
                commitdate = orderdate + rng.rand_int(30, 90)
                receiptdate = shipdate + rng.rand_int(1, 30)

                base_price = 900 + (partkey % 200_000)
                extendedprice = BigDecimal((base_price * quantity).to_s).round(2)
                discount = BigDecimal((rng.rand_int(0, 10) / 100.0).to_s).round(2)
                tax = BigDecimal((rng.rand_int(0, 8) / 100.0).to_s).round(2)
                days_since_receipt = (Date.today - receiptdate).to_i
                returnflag = if days_since_receipt > 365
                               'R'
                             elsif days_since_receipt > 0
                               rng.rand_int(0, 2) == 0 ? 'R' : 'A'
                             else
                               'N'
                             end
                linestatus = shipdate <= Date.today ? 'F' : 'O'
                comment_len = rng.rand_int(15, 50)
                comment = (0...comment_len).map { Tpch::TextPools::SYLLABLES[rng.rand_int(0, Tpch::TextPools::SYLLABLES.length - 1)] }.join

                row = [
                  orderkey,
                  partkey,
                  suppkey,
                  linenumber,
                  quantity,
                  format('%.2f', extendedprice),
                  format('%.2f', discount),
                  format('%.2f', tax),
                  returnflag,
                  linestatus,
                  shipdate,
                  commitdate,
                  receiptdate,
                  Tpch::TextPools::SHIPINSTRUCT[rng.rand_int(0, Tpch::TextPools::SHIPINSTRUCT.length - 1)],
                  Tpch::TextPools::SHIPMODES[rng.rand_int(0, Tpch::TextPools::SHIPMODES.length - 1)],
                  comment
                ]

                buffer << row.map(&format_val).join('|') + '|'
                
                if buffer.size >= CHUNK_SIZE
                  w.send(buffer.join("\n"))
                  buffer.clear
                end
              end
            end

            w.send(buffer.join("\n")) unless buffer.empty?
          end
        end.compact

        workers.each(&:take)

        writer.send(:done)
        writer.take
      end

      private

      def calculate_order_start_id
        return 1 if @total_segments == 1
        
        total_orders = (ORDERS_FACTOR * @scale).to_i
        rows_per_segment = total_orders / @total_segments
        
        (@segment - 1) * rows_per_segment + 1
      end
    end
  end
end

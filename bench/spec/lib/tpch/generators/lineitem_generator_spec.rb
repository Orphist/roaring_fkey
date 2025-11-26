# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'benchmark/ips'
require 'tempfile'

RSpec.describe Tpch::Generators::LineitemGenerator do
  let(:random_gen) { Tpch::RandomGenerator.new(seed: 12345) }
  let(:generator) { described_class.new(scale: 0.01, segment: 1, total_segments: 1, random_gen: random_gen) }

  xdescribe '#generate_in_chunks' do
    let(:generated_chunks) do
      chunks = []
      Tempfile.create('lineitem_output') do |temp_file|
        generator.generate_in_chunks(temp_file.path)
        chunks = File.readlines(temp_file.path)
      end
      chunks
    end

    let(:lineitems) { generated_chunks.flatten }

    it 'yields chunks of lineitems' do
      expect(generated_chunks).not_to be_empty
      expect(generated_chunks.first).to be_an(Array)
      expect(generated_chunks.first.first).to have_key(:orderkey)
    end

    it 'respects the CHUNK_SIZE' do
      generated_chunks.each do |chunk|
        expect(chunk.size).to be <= Tpch::Generators::LineitemGenerator::CHUNK_SIZE
      end
    end

    it 'generates lineitems for all orders' do
      expect(lineitems.count).to be > 0
    end

    it 'includes all required fields' do
      lineitem = lineitems.first
      
      expect(lineitem).to have_key(:orderkey)
      expect(lineitem).to have_key(:partkey)
      expect(lineitem).to have_key(:suppkey)
      expect(lineitem).to have_key(:linenumber)
      expect(lineitem).to have_key(:quantity)
      expect(lineitem).to have_key(:extendedprice)
      expect(lineitem).to have_key(:discount)
      expect(lineitem).to have_key(:tax)
      expect(lineitem).to have_key(:returnflag)
      expect(lineitem).to have_key(:linestatus)
      expect(lineitem).to have_key(:shipdate)
      expect(lineitem).to have_key(:commitdate)
      expect(lineitem).to have_key(:receiptdate)
      expect(lineitem).to have_key(:shipinstruct)
      expect(lineitem).to have_key(:shipmode)
      expect(lineitem).to have_key(:comment)
    end

    it 'generates valid quantity values' do
      lineitems.first(10).each do |lineitem|
        expect(lineitem[:quantity]).to be_between(1, 50)
      end
    end

    it 'generates valid discount values' do
      lineitems.first(10).each do |lineitem|
        expect(lineitem[:discount]).to be_between(0.0, 0.10)
      end
    end

    it 'generates valid tax values' do
      lineitems.first(10).each do |lineitem|
        expect(lineitem[:tax]).to be_between(0.0, 0.08)
      end
    end

    it 'generates valid returnflag values' do
      lineitems.first(10).each do |lineitem|
        expect(lineitem[:returnflag]).to match(/^[RAN]$/)
      end
    end

    it 'generates valid linestatus values' do
      lineitems.first(10).each do |lineitem|
        expect(lineitem[:linestatus]).to match(/^[FO]$/)
      end
    end

    it 'generates linenumbers starting at 1 for each order' do
      first_order_items = lineitems.select { |li| li[:orderkey] == lineitems.first[:orderkey] }
      
      expect(first_order_items.first[:linenumber]).to eq(1)
    end
  end

  xcontext 'flush perf' do
    let(:generator) { described_class.new(scale: 0.01, segment: 1, total_segments: 1, random_gen: random_gen) }

    it 'benchmarks generate vs generate_in_chunks' do
      Benchmark.ips do |x|
        x.config(time: 5, warmup: 1)

        x.report("generate 1 thread") do
          Tempfile.create('lineitem_output') do |temp_file|
            generator.generate_in_chunks(temp_file.path, 1)
          end
        end

        x.report("generate 32 threads") do
          Tempfile.create('lineitem_output') do |temp_file|
            generator.generate_in_chunks(temp_file.path, 32)
          end
        end

        x.compare!
      end
    end
  end

  describe '#generate_in_chunks' do
    it 'generates correct number of lineitems and writes to file' do
      Tempfile.create('lineitem_output') do |temp_file|
        generator.generate_in_chunks(temp_file.path)

        # Read file and count lines
        lines = File.readlines(temp_file.path)

        # We can't easily predict exact line count due to random lineitems per order,
        # but we can check if it's within a reasonable range.
        # Scale 0.01 -> 15,000 orders. Avg 4 lineitems -> ~60,000 lines.
        expect(lines.count).to be_between(50_000, 70_000)

        # Verify format of first line
        first_line = lines.first
        fields = first_line.strip.split('|')

        # orderkey|partkey|suppkey|linenumber|quantity|extendedprice|discount|tax|returnflag|linestatus|shipdate|commitdate|receiptdate|shipinstruct|shipmode|comment|
        expect(fields.length).to eq(16)

        expect(fields[0]).to match(/^\d+$/) # orderkey
        expect(fields[1]).to match(/^\d+$/) # partkey
        expect(fields[5]).to match(/^\d+\.\d{2}$/) # extendedprice (float formatted)
        expect(fields[10]).to match(/^\d{4}-\d{2}-\d{2}$/) # shipdate
      end
    end
  end
end

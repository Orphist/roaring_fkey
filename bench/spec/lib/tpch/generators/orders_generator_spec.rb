# frozen_string_literal: true

require 'tempfile'

require_relative '../../../spec_helper'
require_relative '../../../../lib/tpch/generators/orders_generator'

RSpec.describe Tpch::Generators::OrdersGenerator do
  let(:random_gen) { Tpch::RandomGenerator.new(seed: 12345) }
  let(:generator) { described_class.new(scale: 0.01, segment: 1, total_segments: 1, random_gen: random_gen) }
  
  describe '#generate_in_chunks' do
    it 'generates correct number of orders and writes to file' do
      Tempfile.create('orders_output') do |temp_file|
        generator.generate_in_chunks(temp_file.path)
        
        # Read file and count lines
        lines = File.readlines(temp_file.path)
        expected = Tpch::ScaleCalculator.row_count(:orders, 0.01, 1, 1)
        
        expect(lines.count).to eq(expected)
        
        # Verify format of first line
        first_line = lines.first
        fields = first_line.strip.split('|')
        
        # orderkey|custkey|orderstatus|totalprice|orderdate|orderpriority|clerk|shippriority|comment|
        expect(fields.length).to eq(9) 
        expect(fields[0]).to match(/^\d+$/) # orderkey
        expect(fields[1]).to match(/^\d+$/) # custkey
        expect(fields[2]).to match(/^[FO]$/) # orderstatus
        expect(fields[4]).to match(/^\d{4}-\d{2}-\d{2}$/) # orderdate
      end
    end
  end
end

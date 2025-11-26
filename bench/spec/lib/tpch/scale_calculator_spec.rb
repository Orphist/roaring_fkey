# frozen_string_literal: true

RSpec.describe Tpch::ScaleCalculator do
  describe '.row_count' do
    context 'for fixed-size tables' do
      it 'returns 25 for nation regardless of scale' do
        expect(described_class.row_count(:nation, 1, 1, 1)).to eq(25)
        expect(described_class.row_count(:nation, 10, 1, 1)).to eq(25)
      end

      it 'returns 5 for region regardless of scale' do
        expect(described_class.row_count(:region, 1, 1, 1)).to eq(5)
        expect(described_class.row_count(:region, 10, 1, 1)).to eq(5)
      end
    end

    context 'for scale-dependent tables' do
      it 'calculates customer rows for scale 1' do
        count = described_class.row_count(:customer, 1, 1, 1)
        expect(count).to eq(150_000)
      end

      it 'scales customer rows proportionally' do
        count = described_class.row_count(:customer, 10, 1, 1)
        expect(count).to eq(1_500_000)
      end

      it 'calculates supplier rows for scale 1' do
        count = described_class.row_count(:supplier, 1, 1, 1)
        expect(count).to eq(10_000)
      end

      it 'calculates part rows for scale 1' do
        count = described_class.row_count(:part, 1, 1, 1)
        expect(count).to eq(200_000)
      end
    end

    context 'for parallel segments' do
      it 'partitions customer rows across 4 segments' do
        total = 0
        4.times do |i|
          total += described_class.row_count(:customer, 1, 4, i + 1)
        end
        expect(total).to eq(150_000)
      end

      it 'distributes rows evenly when divisible' do
        segment1 = described_class.row_count(:supplier, 1, 2, 1)
        segment2 = described_class.row_count(:supplier, 1, 2, 2)
        
        expect(segment1).to eq(5_000)
        expect(segment2).to eq(5_000)
      end

      it 'handles remainders in partitioning' do
        segment1 = described_class.row_count(:customer, 1, 4, 1)
        expect(segment1).to be > 0
      end
    end
  end
end

# frozen_string_literal: true

RSpec.describe Tpch::Generators::RegionGenerator do
  let(:random_gen) { Tpch::RandomGenerator.new(seed: 12345) }
  let(:generator) { described_class.new(scale: 1, segment: 1, total_segments: 1, random_gen: random_gen) }

  describe '#generate' do
    it 'generates exactly 5 regions' do
      regions = generator.generate
      expect(regions.count).to eq(5)
    end

    it 'includes required fields' do
      regions = generator.generate
      region = regions.first
      
      expect(region).to have_key(:regionkey)
      expect(region).to have_key(:name)
      expect(region).to have_key(:comment)
    end

    it 'includes all expected regions' do
      regions = generator.generate
      region_names = regions.map { |r| r[:name] }
      
      expect(region_names).to contain_exactly('AFRICA', 'AMERICA', 'ASIA', 'EUROPE', 'MIDDLE EAST')
    end
  end
end

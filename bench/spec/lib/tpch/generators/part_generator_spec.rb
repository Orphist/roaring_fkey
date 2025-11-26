# frozen_string_literal: true

RSpec.describe Tpch::Generators::PartGenerator do
  let(:random_gen) { Tpch::RandomGenerator.new(seed: 12345) }
  let(:generator) { described_class.new(scale: 0.01, segment: 1, total_segments: 1, random_gen: random_gen) }

  describe '#generate' do
    it 'generates correct number of parts for scale' do
      parts = generator.generate
      expected = Tpch::ScaleCalculator.row_count(:part, 0.01, 1, 1)
      expect(parts.count).to eq(expected)
    end

    it 'includes all required fields' do
      parts = generator.generate
      part = parts.first
      
      expect(part).to have_key(:partkey)
      expect(part).to have_key(:name)
      expect(part).to have_key(:mfgr)
      expect(part).to have_key(:brand)
      expect(part).to have_key(:type)
      expect(part).to have_key(:size)
      expect(part).to have_key(:container)
      expect(part).to have_key(:retailprice)
      expect(part).to have_key(:comment)
    end

    it 'generates valid partkey values' do
      parts = generator.generate
      
      parts.each_with_index do |part, index|
        expect(part[:partkey]).to eq(index + 1)
      end
    end

    it 'generates part names with 5 syllables' do
      parts = generator.generate
      
      parts.first(10).each do |part|
        syllables = part[:name].split
        expect(syllables.length).to eq(5)
      end
    end

    it 'generates valid mfgr values' do
      parts = generator.generate
      
      parts.each do |part|
        expect(part[:mfgr]).to match(/^Manufacturer#\d$/)
        mfgr_num = part[:mfgr].split('#').last.to_i
        expect(mfgr_num).to be_between(1, 5)
      end
    end

    it 'generates valid brand values' do
      parts = generator.generate
      
      parts.each do |part|
        expect(part[:brand]).to match(/^Brand#\d+$/)
        brand_num = part[:brand].split('#').last.to_i
        expect(brand_num).to be_between(10, 55)
      end
    end

    it 'generates valid type values' do
      parts = generator.generate
      
      parts.each do |part|
        type_parts = part[:type].split
        expect(type_parts.length).to eq(3)
        expect(Tpch::Generators::PartGenerator::PART_TYPES).to include(type_parts[0])
        expect(Tpch::Generators::PartGenerator::PART_FINISHES).to include(type_parts[1])
        expect(Tpch::Generators::PartGenerator::PART_MATERIALS).to include(type_parts[2])
      end
    end

    it 'generates valid size values' do
      parts = generator.generate
      
      parts.each do |part|
        expect(part[:size]).to be_between(1, 50)
      end
    end

    it 'generates valid container values' do
      parts = generator.generate
      
      parts.each do |part|
        expect(Tpch::TextPools::CONTAINER_TYPES).to include(part[:container])
      end
    end

    it 'generates valid retailprice values' do
      parts = generator.generate
      
      parts.each do |part|
        expect(part[:retailprice]).to be_a(BigDecimal)
        expect(part[:retailprice]).to be > 0
      end
    end

    it 'generates comments as strings' do
      parts = generator.generate
      
      parts.each do |part|
        expect(part[:comment]).to be_a(String)
      end
    end
  end
end
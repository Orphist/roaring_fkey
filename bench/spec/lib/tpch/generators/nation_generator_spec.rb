# frozen_string_literal: true

RSpec.describe Tpch::Generators::NationGenerator do
  let(:random_gen) { Tpch::RandomGenerator.new(seed: 12345) }
  let(:generator) { described_class.new(scale: 1, segment: 1, total_segments: 1, random_gen: random_gen) }

  describe '#generate' do
    it 'generates exactly 25 nations' do
      nations = generator.generate
      expect(nations.count).to eq(25)
    end

    it 'includes required fields' do
      nations = generator.generate
      nation = nations.first
      
      expect(nation).to have_key(:nationkey)
      expect(nation).to have_key(:name)
      expect(nation).to have_key(:regionkey)
      expect(nation).to have_key(:comment)
    end

    it 'each nation has valid regionkey 0-4' do
      nations = generator.generate
      
      nations.each do |nation|
        expect(nation[:regionkey]).to be_between(0, 4)
      end
    end

    it 'generates unique nation keys' do
      nations = generator.generate
      nation_keys = nations.map { |n| n[:nationkey] }
      
      expect(nation_keys.uniq.size).to eq(25)
    end

    it 'includes expected nations' do
      nations = generator.generate
      nation_names = nations.map { |n| n[:name] }
      
      expect(nation_names).to include('ALGERIA', 'BRAZIL', 'CHINA', 'FRANCE', 'UNITED STATES')
    end
  end
end

# frozen_string_literal: true

RSpec.describe Tpch::Generators::CustomerGenerator do
  let(:random_gen) { Tpch::RandomGenerator.new(seed: 12345) }
  let(:generator) { described_class.new(scale: 0.01, segment: 1, total_segments: 1, random_gen: random_gen) }

  describe '#generate' do
    it 'generates correct number of customers for scale' do
      customers = generator.generate
      expected = Tpch::ScaleCalculator.row_count(:customer, 0.01, 1, 1)
      expect(customers.count).to eq(expected)
    end

    it 'includes all required fields' do
      customers = generator.generate
      customer = customers.first
      
      expect(customer).to have_key(:custkey)
      expect(customer).to have_key(:name)
      expect(customer).to have_key(:address)
      expect(customer).to have_key(:nationkey)
      expect(customer).to have_key(:phone)
      expect(customer).to have_key(:acctbal)
      expect(customer).to have_key(:mktsegment)
      expect(customer).to have_key(:comment)
    end

    it 'generates valid nationkey values' do
      customers = generator.generate
      
      customers.each do |customer|
        expect(customer[:nationkey]).to be_between(0, 24)
      end
    end

    it 'generates customer names in correct format' do
      customers = generator.generate
      
      customers.first(10).each do |customer|
        expect(customer[:name]).to match(/^Customer#\d{9}$/)
      end
    end
  end
end

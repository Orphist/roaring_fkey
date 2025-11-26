# frozen_string_literal: true

RSpec.describe Tpch::RandomGenerator do
  describe '#initialize' do
    it 'accepts a seed parameter' do
      expect { described_class.new(seed: 12345) }.not_to raise_error
    end
  end

  describe '#rand_int' do
    it 'generates deterministic sequences with same seed' do
      randoms1 = described_class.new(seed: 12345)
      randoms2 = described_class.new(seed: 12345)
      
      10.times do
        expect(randoms1.rand_int(1, 100)).to eq(randoms2.rand_int(1, 100))
      end
    end
    
    it 'generates different sequences with different seeds' do
      randoms1 = described_class.new(seed: 12345)
      randoms2 = described_class.new(seed: 67890)
      
      expect(randoms1.rand_int(1, 100)).not_to eq(randoms2.rand_int(1, 100))
    end

    it 'generates values within specified range' do
      random_gen = described_class.new(seed: 99999)
      
      100.times do
        value = random_gen.rand_int(10, 50)
        expect(value).to be_between(10, 50)
      end
    end
  end

  describe '#rand_string' do
    it 'formats pattern strings with numbers' do
      random_gen = described_class.new(seed: 42)
      result = random_gen.rand_string('Customer#%09d')
      
      expect(result).to match(/^Customer#\d{9}$/)
    end
  end

  describe '#rand_date' do
    it 'generates dates within specified range' do
      random_gen = described_class.new(seed: 77777)
      start_date = Date.new(1992, 1, 1)
      end_date = Date.new(1998, 12, 31)
      
      10.times do
        date = random_gen.rand_date(start_date, end_date)
        expect(date).to be_between(start_date, end_date)
      end
    end
  end
end

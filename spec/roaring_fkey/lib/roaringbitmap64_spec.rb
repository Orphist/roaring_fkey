# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'RoaringBitmap64', :aggregate_failures, :db do
  let(:connection) { ActiveRecord::Base.connection }

  before do
    connection.execute("DROP TABLE IF EXISTS test_roaringbitmap64_models")
    connection.execute("DROP TABLE IF EXISTS test_associated_models")
    
    connection.create_table(:test_roaringbitmap64_models) do |t|
      t.string :name
      t.roaringbitmap64 :item_ids
    end
    
    connection.create_table :test_associated_models, id: false do |t|
      t.string :name
      t.bigint :id
    end
  end

  after do
    connection.execute("DROP TABLE IF EXISTS test_roaringbitmap64_models")
    connection.execute("DROP TABLE IF EXISTS test_associated_models")
  end

  describe 'basic operations' do
    let(:model_class) do
      Class.new(ActiveRecord::Base) do
        self.table_name = 'test_roaringbitmap64_models'
      end
    end

    let(:associated_class) do
      Class.new(ActiveRecord::Base) do
        self.table_name = 'test_associated_models'
        self.primary_key = 'id'
      end
    end

    it 'can create a record with roaringbitmap64 field' do
      record = model_class.create!(name: 'test', item_ids: [1, 2, 3])
      expect(record.item_ids).to eq([1, 2, 3])
    end

    it 'can handle bigint values' do
      large_id = 9223372036854775807 # max bigint value
      record = model_class.create!(name: 'test', item_ids: [large_id, 123])
      expect(record.item_ids).to include(large_id)
      expect(record.item_ids).to include(123)
    end

    it 'can update roaringbitmap64 field' do
      record = model_class.create!(name: 'test', item_ids: [1, 2, 3])
      record.update!(item_ids: [4, 5, 6])
      expect(record.item_ids).to eq([4, 5, 6])
    end

    it 'can handle empty arrays' do
      record = model_class.create!(name: 'test', item_ids: [])
      expect(record.item_ids).to eq([])
    end

    it 'can handle nil values' do
      record = model_class.create!(name: 'test', item_ids: nil)
      expect(record.item_ids).to eq([])
    end
  end

  describe 'SQL functions' do
    it 'has roaringbitmap64 functions installed' do
      functions = connection.select_values(
        "SELECT proname FROM pg_proc WHERE proname LIKE 'roaring_fkey_%64%'"
      )
      expect(functions).to include('roaring_fkey_bigint_contains_in_bitmap64')
      expect(functions).to include('roaring_fkey_bitmap_overlaps_array_bigint64')
    end

    it 'has roaringbitmap64 aggregate functions' do
      aggregates = connection.select_values(
        "SELECT proname FROM pg_proc WHERE proname LIKE 'roaring_fkey_%'"
      )
      expect(aggregates).to include('roaring_fkey_bitmap64_count')
      expect(aggregates).to include('roaring_fkey_bitmap64_max')
      expect(aggregates).to include('roaring_fkey_bitmap64_min')
    end
  end

  describe 'operators' do
    let(:model_class) do
      Class.new(ActiveRecord::Base) do
        self.table_name = 'test_roaringbitmap64_models'
      end
    end

    it 'supports contains operator with bigint' do
      record = model_class.create!(name: 'test', item_ids: [1000000000, 2000000000])
      
      # Test the @> operator (contains)
      result = connection.select_value(
        "SELECT item_ids @> 1000000000::bigint FROM test_roaringbitmap64_models WHERE name = 'test'"
      )
      expect(result).to be true
    end

    it 'supports contains operator with bigint array' do
      record = model_class.create!(name: 'test', item_ids: [1000000000, 2000000000, 3000000000])
      
      # Test the && operator (overlaps)
      result = connection.select_value(
        "SELECT item_ids && ARRAY[1000000000, 4000000000]::bigint[] FROM test_roaringbitmap64_models WHERE name = 'test'"
      )
      expect(result).to be true
    end

    it 'uses rb64_build function for roaringbitmap64' do
      # Test that rb64_build function is used correctly
      result = connection.select_value(
        "SELECT rb64_build(ARRAY[1000000000, 2000000000]) && rb64_build(ARRAY[2000000000, 3000000000])"
      )
      expect(result).to be true
    end
  end
end
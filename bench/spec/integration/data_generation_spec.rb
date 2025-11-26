# frozen_string_literal: true

require 'tmpdir'
require 'fileutils'

RSpec.describe 'TPC-H Data Generation' do
  let(:output_dir) { Dir.mktmpdir }
  
  after { FileUtils.rm_rf(output_dir) }
  
  describe 'full generation workflow' do
    it 'generates all 8 tables for scale 0.01' do
      generator = Tpch::DataGenerator.new(
        scale: 0.01,
        output_dir: output_dir,
        segment_id: 1,
        parallel_count: 1,
        verbose: false
      )
      
      generator.generate
      
      expect(File.exist?("#{output_dir}/nation.tbl.1")).to be true
      expect(File.exist?("#{output_dir}/region.tbl.1")).to be true
      expect(File.exist?("#{output_dir}/customer.tbl.1")).to be true
      expect(File.exist?("#{output_dir}/supplier.tbl.1")).to be true
      expect(File.exist?("#{output_dir}/part.tbl.1")).to be true
      expect(File.exist?("#{output_dir}/partsupp.tbl.1")).to be true
      expect(File.exist?("#{output_dir}/orders.tbl.1")).to be true
      expect(File.exist?("#{output_dir}/lineitem.tbl.1")).to be true
    end
    
    it 'generates files with non-zero content' do
      generator = Tpch::DataGenerator.new(
        scale: 0.01,
        output_dir: output_dir,
        segment_id: 1,
        parallel_count: 1,
        verbose: false
      )
      
      generator.generate
      
      Dir.glob("#{output_dir}/*.tbl.1").each do |file|
        expect(File.size(file)).to be > 0
      end
    end
  end

  describe 'file format validation' do
    before do
      generator = Tpch::DataGenerator.new(
        scale: 0.01,
        output_dir: output_dir,
        segment_id: 1,
        parallel_count: 1,
        verbose: false
      )
      generator.generate
    end

    it 'generates pipe-delimited format with trailing pipe' do
      first_line = File.readlines("#{output_dir}/nation.tbl.1").first
      expect(first_line).to match(/\|$/)
    end

    it 'nation.tbl has correct number of fields' do
      first_line = File.readlines("#{output_dir}/nation.tbl.1").first
      expect(first_line.count('|')).to eq(4)
    end

    it 'customer.tbl has correct number of fields' do
      first_line = File.readlines("#{output_dir}/customer.tbl.1").first
      expect(first_line.count('|')).to eq(8)
    end
  end

  describe 'data integrity' do
    before do
      generator = Tpch::DataGenerator.new(
        scale: 0.01,
        output_dir: output_dir,
        segment_id: 1,
        parallel_count: 1,
        verbose: false
      )
      generator.generate
    end

    it 'generates exactly 25 nations' do
      lines = File.readlines("#{output_dir}/nation.tbl.1")
      expect(lines.count).to eq(25)
    end

    it 'generates exactly 5 regions' do
      lines = File.readlines("#{output_dir}/region.tbl.1")
      expect(lines.count).to eq(5)
    end

    it 'generates correct number of customers for scale' do
      lines = File.readlines("#{output_dir}/customer.tbl.1")
      expected = Tpch::ScaleCalculator.row_count(:customer, 0.01, 1, 1)
      expect(lines.count).to eq(expected)
    end
  end

  describe 'deterministic generation' do
    it 'produces identical output with same parameters' do
      generator1 = Tpch::DataGenerator.new(
        scale: 0.01,
        output_dir: output_dir,
        segment_id: 1,
        parallel_count: 1,
        verbose: false
      )
      generator1.generate
      
      content1 = File.read("#{output_dir}/customer.tbl.1")
      
      FileUtils.rm_rf(output_dir)
      FileUtils.mkdir_p(output_dir)
      
      generator2 = Tpch::DataGenerator.new(
        scale: 0.01,
        output_dir: output_dir,
        segment_id: 1,
        parallel_count: 1,
        verbose: false
      )
      generator2.generate
      
      content2 = File.read("#{output_dir}/customer.tbl.1")
      
      expect(content1).to eq(content2)
    end
  end
end

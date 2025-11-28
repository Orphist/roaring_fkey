# frozen_string_literal: true

require "spec_helper"
require "generators/roaring_fkey/install/install_generator"

describe RoaringFkey::Generators::InstallGenerator, :aggregate_failures, type: :generator do
  tests described_class
  destination File.expand_path("../../tmp", __dir__)

  let(:args) { ["roaring_fkey:install"] }
  let(:ar_version) { "6.0" }

  before do
    prepare_destination
    allow(ActiveRecord::Migration).to receive(:current_version).and_return(ar_version)
  end

  after do
    FileUtils.rm(migration_path) if migration_path
  end

  describe "installing" do
    let(:migration_path) { Dir[File.join(destination_root, "db/migrate/*roaring_fkey_install.rb")].first }

    context "when not installed yet" do
      before do
        allow_any_instance_of(described_class).to receive(:installed_recent_version?).and_return(false)
      end

      it "creates migration" do
        run_generator(args)

        expect(File.exist?(migration_path)).to be true
        migration = File.open(migration_path).readlines.join
        expect(migration).to  include "class RoaringFkeyInstall < ActiveRecord::Migration[#{ar_version}]"
        expect(migration).to  include "CREATE FUNCTION roaring_fkey_bigint_contains_in_bitmap64"
        expect(migration).to  include "CREATE FUNCTION roaring_fkey_bigint_contains_int_array"
        expect(migration).to  include "CREATE FUNCTION roaring_fkey_bigint_eq_int_array"
        expect(migration).to  include "CREATE FUNCTION roaring_fkey_bitmap64_count"
        expect(migration).to  include "CREATE FUNCTION roaring_fkey_bitmap64_max"
        expect(migration).to  include "CREATE FUNCTION roaring_fkey_bitmap64_min"
        expect(migration).to  include "CREATE FUNCTION roaring_fkey_bitmap_contains_bigint64"
        expect(migration).to  include "CREATE FUNCTION roaring_fkey_bitmap_contains_int"
        expect(migration).to  include "CREATE FUNCTION roaring_fkey_bitmap_count"
        expect(migration).to  include "CREATE FUNCTION roaring_fkey_bitmap_max"
        expect(migration).to  include "CREATE FUNCTION roaring_fkey_bitmap_min"
        expect(migration).to  include "CREATE FUNCTION roaring_fkey_bitmap_overlaps_array_bigint64"
        expect(migration).to  include "CREATE FUNCTION roaring_fkey_bitmap_overlaps_array_int"
        expect(migration).to  include "CREATE FUNCTION roaring_fkey_int_array_contains_bigint"
        expect(migration).to  include "CREATE FUNCTION roaring_fkey_int_contains_in_bitmap"
        expect(migration).to  include "CREATE FUNCTION roaring_fkey_version"
      end
    end

    context "when installed already" do
      before do
        allow_any_instance_of(described_class).to receive(:installed_recent_version?).and_return(true)
      end

      it "migration file not created" do
        run_generator(args)

        expect(migration_path).to be_nil
      end
    end
  end

  describe "installing w/update" do
    let(:migration_path) { Dir[File.join(destination_root, "db/migrate/*roaring_fkey_update_#{::RoaringFkey::VERSION.delete(".")}.rb")].first }
    let(:args) { ["--update"] }

    context "when not installed yet" do
      before do
        allow_any_instance_of(described_class).to receive(:installed_recent_version?).and_return(false)
      end

      it "creates migration" do
        run_generator(args)

        expect(File.exist?(migration_path)).to be true
        migration = File.open(migration_path).readlines.join
        expect(migration).to  include "class RoaringFkeyUpdate#{::RoaringFkey::VERSION.delete(".")} < ActiveRecord::Migration[#{ar_version}]"
        expect(migration).to  include "DROP FUNCTION IF EXISTS roaring_fkey_int_array_contains_bigint"
        expect(migration).to  include "CREATE FUNCTION roaring_fkey_int_array_contains_bigint"
        expect(migration).to  include "DROP FUNCTION IF EXISTS roaring_fkey_bigint_contains_int_array"
        expect(migration).to  include "CREATE FUNCTION roaring_fkey_bigint_contains_int_array"
        expect(migration).to  include "DROP FUNCTION IF EXISTS roaring_fkey_bigint_contains_in_bitmap"
        expect(migration).to  include "CREATE FUNCTION roaring_fkey_bigint_contains_in_bitmap"
        expect(migration).to  include "DROP FUNCTION IF EXISTS roaring_fkey_int_contains_in_bitmap"
        expect(migration).to  include "CREATE FUNCTION roaring_fkey_int_contains_in_bitmap"
        expect(migration).to  include "DROP FUNCTION IF EXISTS roaring_fkey_bitmap_contains_bigint"
        expect(migration).to  include "CREATE FUNCTION roaring_fkey_bitmap_contains_bigint"
        expect(migration).to  include "DROP FUNCTION IF EXISTS roaring_fkey_bitmap_overlaps_array_int"
        expect(migration).to  include "CREATE FUNCTION roaring_fkey_bitmap_overlaps_array_int"
        expect(migration).to  include "DROP FUNCTION IF EXISTS roaring_fkey_bitmap_contains_int"
        expect(migration).to  include "CREATE FUNCTION roaring_fkey_bitmap_contains_int"
        expect(migration).to  include "DROP FUNCTION IF EXISTS roaring_fkey_version"
        expect(migration).to  include "CREATE FUNCTION roaring_fkey_version"
      end
    end

    context "when installed already" do
      before do
        allow_any_instance_of(described_class).to receive(:installed_recent_version?).and_return(true)
      end

      it "migration file not created" do
        run_generator(args)

        expect(migration_path).to be_nil
      end
    end
  end

  describe "roaringbitmap migration" do
    let(:migration_path) { Dir[File.join(destination_root, "db/migrate/*enable_roaringbitmap.rb")].first }

    context "when not installed yet" do
      before do
        allow_any_instance_of(described_class).to receive(:installed_recent_version?).and_return(false)
      end

      it "creates migration" do
        run_generator(args)

        expect(File.exist?(migration_path)).to be true
        migration = File.open(migration_path).readlines.join
        expect(migration).to  include "class EnableRoaringbitmap < ActiveRecord::Migration[#{ar_version}]"
        expect(migration).to  include "enable_extension :roaringbitmap"
      end
    end

    context "when installed already" do
      before do
        allow_any_instance_of(described_class).to receive(:installed_recent_version?).and_return(true)
      end

      it "migration file not created" do
        run_generator(args)

        expect(migration_path).to be_nil
      end
    end
  end
end

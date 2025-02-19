# frozen_string_literal: true

require "spec_helper"
require "generators/roaring_fkey/model/model_generator"

describe RoaringFkey::Generators::ModelGenerator, :aggregate_failures, type: :generator do
  # from Railties
  #   class AppGeneratorTest < Rails::Generators::TestCase
  #     tests AppGenerator
  #     destination File.expand_path("../tmp", __dir__)
  #     setup :prepare_destination
  #
  #     test "database.yml is not created when skipping Active Record" do
  #       run_generator %w(myapp --skip-active-record)
  #       assert_no_file "config/database.yml"
  #     end
  #   end
  tests described_class
  destination File.expand_path("../../tmp", __dir__)

  def full_table_name(table_name)
    table_name
  end

  let(:args) { args }
  let(:ar_version) { "6.0" }
  let(:model_path) { File.join(destination_root, "app", "models", "user_group.rb") }

  before do
    prepare_destination
    FileUtils.mkdir_p(File.dirname(model_path))
    allow(ActiveRecord::Migration).to receive(:current_version).and_return(ar_version)
  end

  after do
    prepare_destination
    FileUtils.rm_rf(destination_root)
  end

  describe "migration" do
    context "without namespace" do
      let(:migration_path) { Dir[File.join(destination_root, "db", "migrate", "*add_roaring_fkey_user_ids_to_user_groups.rb")].first }
      # rails generate roaring_fkey:model user_group user:references
      let(:args) { ["user_group", "user:references"] }

      before do
        File.write(
          model_path,
          <<~RAW
            class UserGroup < ActiveRecord::Base
            end
          RAW
        )
      end

      it "creates migration" do
        run_generator(args)

        expect(File.exist?(model_path)).to be true
        expect(File.open(model_path).readlines.join).to include "belongs_to_many :users, anonymous_class: User, foreign_key: :user_ids, inverse_of: false"
        expect(File.exist?(migration_path)).to be true
        model_migration = File.open(migration_path).readlines
        expect(model_migration[0]).to include "class AddRoaringFkeyUserIdsToUserGroups < ActiveRecord::Migration[#{ar_version}]"
        expect(model_migration[2]).to include "add_column :user_groups, :user_ids, :roaringbitmap, default: '\\x3a3000000100000000000000100000000000'"
      end
    end

    context "with namespace" do
      let(:migration_path) { Dir[File.join(destination_root, "db", "migrate", "*add_roaring_fkey_user_ids_to_user_guests.rb")].first }
      let(:model_path) { File.join(destination_root, "app", "models", "user", "guest.rb") }

      let(:args) { ["user/guest", "user:references"] }

      before do
        File.write(
          model_path,
          <<~RAW
            module User
              class Guest < ActiveRecord::Base
              end
            end
          RAW
        )
      end

      it "creates migration" do
        run_generator(args)

        expect(File.exist?(migration_path)).to be true
        expect(File.exist?(model_path)).to be true
        expect(File.open(model_path).readlines.join).to include "belongs_to_many :users, anonymous_class: User, foreign_key: :user_ids, inverse_of: false"
      end
    end

    context "with custom path" do
      let(:migration_path) { Dir[File.join(destination_root, "db", "migrate", "*add_roaring_fkey_file_ids_to_data_sets.rb")].first }
      let(:model_path) { File.join(destination_root, "app", "models", "custom", "data", "set.rb") }

      let(:args) { ["data/set", "file:references", "--path", "app/models/custom/data/set.rb"] }

      before do
        File.write(
          model_path,
          <<~RAW
            module Data
              class Set < ActiveRecord::Base
              end
            end
          RAW
        )
      end

      it "creates migration" do
        run_generator(args)

        expect(File.exist?(model_path)).to be true
        expect(File.open(model_path).readlines.join).to include "belongs_to_many :files, anonymous_class: File, foreign_key: :file_ids, inverse_of: false"

        expect(File.exist?(migration_path)).to be true
        model_migration = File.open(migration_path).readlines
        expect(model_migration[0]).to include "class AddRoaringFkeyFileIdsToDataSets < ActiveRecord::Migration[#{ar_version}]"
        expect(model_migration[2]).to include "add_column :data_sets, :file_ids, :roaringbitmap, default: '\\x3a3000000100000000000000100000000000'"
      end
    end

    context "with errors in args" do
      let(:migration_path) { Dir[File.join(destination_root, "db", "migrate", "*add_roaring_fkey_file_ids_to_data_sets.rb")].first }
      let(:model_path) { File.join(destination_root, "app", "models", "custom", "data", "set.rb") }

      let(:args) { ["data/set", "file:references", "--path", "app/models/custom/data/set.rb"] }

      before do
        File.write(
          model_path,
          <<~RAW
            module Data
              class Set < ActiveRecord::Base
              end
            end
          RAW
        )
      end

      it "creates migration" do
        run_generator(args)

        expect(File.exist?(model_path)).to be true
        expect(File.open(model_path).readlines.join).to include "belongs_to_many :files, anonymous_class: File, foreign_key: :file_ids, inverse_of: false"

        expect(File.exist?(migration_path)).to be true
        model_migration = File.open(migration_path).readlines
        expect(model_migration[0]).to include "class AddRoaringFkeyFileIdsToDataSets < ActiveRecord::Migration[#{ar_version}]"
        expect(model_migration[2]).to include "add_column :data_sets, :file_ids, :roaringbitmap, default: '\\x3a3000000100000000000000100000000000'"
      end
    end
  end
end

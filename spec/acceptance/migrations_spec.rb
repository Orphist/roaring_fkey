# frozen_string_literal: true

require "acceptance_helper"
require "generators/roaring_fkey/install/install_generator"

describe "RoaringFkey migrations" do
  describe "#install" do
    let(:roaring_fkey_command) do
      "ActiveRecord::Base.connection.execute %q{SELECT 5::bigint = ARRAY[5]}"
    end

    include_context "cleanup migrations"

    before do
      Dir.chdir("#{File.dirname(__FILE__)}/../dummy") do
        successfully "rake db:migrate"
      end
      allow_any_instance_of(RoaringFkey::Generators::InstallGenerator).to receive(:installed_recent_version?).and_return(false)
    end

    after(:all) do
      Dir.chdir("#{File.dirname(__FILE__)}/../dummy") do
        successfully "rake db:migrate"
      end
    end

    it "rollbacks" do
      successfully "rails generate roaring_fkey:install"
      successfully "rake db:migrate"
      successfully %(
        rails runner "#{roaring_fkey_command}"
      )
      successfully "rake db:rollback"
      unsuccessfully %(
        rails runner "#{roaring_fkey_command}"
      )
    end

    it "creates update migration" do
      successfully "rails generate roaring_fkey:install"
      successfully "rake db:migrate"
      successfully %(
        rails runner "#{roaring_fkey_command}"
      )
      successfully "rake db:rollback"
    end
  end

  xdescribe "#model" do
    include_context "cleanup migrations"
    include_context "cleanup models"

    let(:roaring_fkey_command) do
      <<-RUBY
        movie = Movie.create!(title: 'Elm street');
        movie.actors << Actor.create(name: 'mr Duddle');
        movie.save;  
        movie.reload.actor_ids == [1] || raise('Check failed!');
      RUBY
    end

    before do
      successfully "rails generate model Movie title:text"
      successfully "rails generate model Actors name:text"
      successfully "rake db:migrate"
    end

    it "creates migration and patches model" do
      successfully "rails generate roaring_fkey:model Movie actor:references"

      verify_file_contains "app/models/movie.rb", "belongs_to_many :actors"

      successfully "rake db:migrate"

      successfully %(
        rails runner "#{roaring_fkey_command}"
      )

      successfully "rake db:rollback"

      unsuccessfully %(
        rails runner "#{roaring_fkey_command}"
      )
    end
  end
end

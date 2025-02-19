# frozen_string_literal: true

require "spec_helper"

require "digest/sha1"

# For faster development, let's not re-create a database for every test run,
# only if SQL functions has changed
#
# Heavily inspired by Webpacker: https://github.com/rails/webpacker/blob/master/lib/webpacker/compiler.rb
module ConditionalDatabaseReset
  class << self
    def tmp_path
      @tmp_path ||= Pathname.new(File.join(__dir__, "..", "tmp"))
    end

    def digest_path
      @digest_path ||= tmp_path.join("test_db.digest")
    end

    def watched_files_patterns
      [
        File.join(__dir__, "..", "lib/generators/roaring_fkey/install/functions/*.sql"),
        File.join(__dir__, "..", "lib/generators/roaring_fkey/install/templates/*")
      ]
    end

    def stale?
      last_digest != watched_files_digest || ENV["FORCE_DB_RESET"]
    end

    def last_digest
      digest_path.read if digest_path.exist?
    rescue Errno::ENOENT, Errno::ENOTDIR
    end

    def watched_files_digest
      @watched_files_digest ||=
        begin
          files = Dir[*watched_files_patterns].reject { |f| File.directory?(f) }
          file_ids = files.sort.map { |f| "#{File.basename(f)}/#{Digest::SHA1.file(f).hexdigest}" }
          Digest::SHA1.hexdigest(file_ids.join("/"))
        end
    end

    def record_digest
      tmp_path.mkpath
      digest_path.write(watched_files_digest)
    end
  end
end

RSpec.configure do |config|
  config.include RoaringFkey::AcceptanceHelpers
  config.include RoaringFkey::PostgresHelpers

  config.around(:each) do |example|
    Dir.chdir("#{File.dirname(__FILE__)}/dummy") do
      example.run
    end
  end

  migrations_to_delete = []

  config.before(:suite) do
    Dir.chdir("#{File.dirname(__FILE__)}/dummy") do
      if ConditionalDatabaseReset.stale?
        start = Time.now
        ActiveRecord::Base.connection_pool.disconnect!

        $stdout.puts "✩₊˚.⋆🕸  Creating database and installing RoaringFkey... "

        migrations_to_delete << Dir.glob("db/migrate/*_enable_roaringbitmap.rb").first
        migrations_to_delete << Dir.glob("db/migrate/*_roaring_fkey_install.rb").first
        migrations_to_delete.compact.each { |path| File.delete(path) }

        RoaringFkey::AcceptanceHelpers.suppress_output do
          system <<-CMD
            rails db:drop db:create db:environment:set RAILS_ENV=test
            rails generate roaring_fkey:install
            rails db:migrate
          CMD
        end

        $stdout.puts "\nDone in #{Time.now - start}s"

        ConditionalDatabaseReset.record_digest

        ActiveRecord::Base.connection_pool.disconnect!
      else
        $stdout.puts "⁂⁂⁂ Database is up-to-date!"
      end
    end
  end
end

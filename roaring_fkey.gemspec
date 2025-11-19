# -*- encoding: utf-8 -*-
$:.push File.expand_path('../lib', __FILE__)

require 'roaring_fkey/version'

Gem::Specification.new do |s|
  s.name = 'roaring_fkey'
  s.version = RoaringFkey::VERSION
  s.summary = 'Foreign key with RoaringBitmap for AR/Rails'
  s.description = 'Adds a RoaringBitmap in foreign key based on belongs_to_many model association'

  s.required_ruby_version     = '>= 2.7.0'
  s.required_rubygems_version = '>= 2.1.5'

  s.author            = 'Orphist'
  s.email             = 'orphist@gmail.com'
  s.homepage          = 'http://github.com/orphist/roaring_fkey'

  s.require_paths = ['lib']

  s.files = %w(LICENSE.md CHANGELOG.md README.md Rakefile) + Dir['lib/**/*rb']

  s.add_dependency 'activerecord', '~> 6.1'
  s.add_dependency 'activesupport', '~> 6.1'
  s.add_dependency 'railties', '~> 6.1'
  s.add_dependency 'pg', '>= 1.2'

  s.add_development_dependency 'rake', '~> 12.3', '>= 12.3.3'
  s.add_development_dependency 'dotenv', '~> 2.1', '>= 2.1.1'
  s.add_development_dependency 'rspec', '~> 3.5', '>= 3.5.0'
  s.add_development_dependency 'rspec-rails', '~> 3.5', '>= 3.5.0'
  s.add_development_dependency 'factory_bot', '~> 6.2', '>= 6.2.1'
  s.add_development_dependency 'faker', '~> 2.20'

  s.add_dependency 'byebug'
  s.add_dependency 'pry'
  s.add_dependency 'pry-byebug'
end

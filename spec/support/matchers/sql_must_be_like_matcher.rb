# frozen_string_literal: true

RSpec::Matchers.define :must_be_like do |expected|
  match do |sql|
    sql.gsub(/\s+/, " ").strip.include? expected.gsub(/\s+/, " ").strip
  end
end

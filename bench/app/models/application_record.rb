# frozen_string_literal: true

require "active_support/number_helper"

class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
  self.table_name_prefix = ''

  def self.random(offset = 1, limit = 1)
    rel = order("random()")
    limit == 1 ? rel.offset(offset).first : rel.offset(offset).take(limit)
  end

  def self.random_ids(limit = 1)
    result = random(1, limit)
    limit == 1 ? result.id : result.map(&:id)
  end

  def self.pretty_count
    ::ActiveSupport::NumberHelper::number_to_delimited((count/1_000.0).round(1), delimiter: "_").to_s + "k"
  end
end

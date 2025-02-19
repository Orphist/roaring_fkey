# frozen_string_literal: true

class RoaringFkey::Book < ::RoaringFkey::ApplicationRecord
  belongs_to_many :reviews, anonymous_class: RoaringFkey::Review, foreign_key: :review_ids, inverse_of: false
  belongs_to_many :orders, anonymous_class: RoaringFkey::Order, foreign_key: :order_ids, inverse_of: false

  scope :in_print, -> { where(out_of_print: false) }
  scope :out_of_print, -> { where(out_of_print: true) }
  scope :old, -> { where(year_published: ...50.years.ago.year) }
  scope :out_of_print_and_expensive, -> { out_of_print.where("price > 500") }
  scope :costs_more_than, ->(amount) { where("price > ?", amount) }
end

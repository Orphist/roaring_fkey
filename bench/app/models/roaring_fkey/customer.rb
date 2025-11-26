# frozen_string_literal: true

class RoaringFkey::Customer < RoaringFkey::ApplicationRecord
  belongs_to_many :orders, anonymous_class: RoaringFkey::Order, foreign_key: :order_ids, inverse_of: false
  belongs_to_many :reviews, anonymous_class: RoaringFkey::Review, foreign_key: :review_ids, inverse_of: false
end
# frozen_string_literal: true

class RoaringFkey::Customer < RoaringFkey::ApplicationRecord
  belongs_to_many :orders, anonymous_class: RoaringFkey::Order, foreign_key: :order_ids, inverse_of: false#, { where("customer_id = roaring_fkey_customers.id") }
  belongs_to_many :reviews, anonymous_class: RoaringFkey::Review, foreign_key: :review_ids, inverse_of: false
end
# module CommentScopes
#   scope :limit_by, lambda { |l| limit(l) }
#   scope :containing, ->(substring) { where("comments.body LIKE '%?%'", substring) }
#   scope :not_again, -> { where("comments.body NOT LIKE '%again%'") }
#   scope :find_by_post, ->(post_id) { where(post_id: post_id) }
#   scope :find_by__author, ->(author_id) { joins(:post).where("posts.author_id": author_id) }
#   scope :ordered_by_post_id, -> { order("comments.post_id DESC") }
# end
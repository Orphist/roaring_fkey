# frozen_string_literal: true

class Customer < ApplicationRecord
  has_many :orders
  has_many :reviews
end
# module CommentScopes
#   scope :limit_by, lambda { |l| limit(l) }
#   scope :containing, ->(substring) { where("comments.body LIKE '%?%'", substring) }
#   scope :not_again, -> { where("comments.body NOT LIKE '%again%'") }
#   scope :find_by_post, ->(post_id) { where(post_id: post_id) }
#   scope :find_by__author, ->(author_id) { joins(:post).where("posts.author_id": author_id) }
#   scope :ordered_by_post_id, -> { order("comments.post_id DESC") }
# end
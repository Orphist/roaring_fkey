# frozen_string_literal: true

# require "models/author"
# require "models/book"

class RoaringFkey::Order < ::RoaringFkey::ApplicationRecord
  # belongs_to :customer, foreign_key: :roaring_fkey_customer_id
  belongs_to_many :books, anonymous_class: RoaringFkey::Book, foreign_key: :book_ids, inverse_of: false

  enum status: { shipped: 0,  being_packed: 1,  complete: 2, cancelled: 3 } # [:shipped, :being_packed, :complete, :cancelled]

  scope :created_before, ->(time) { where(created_at: ...time) }
end

# class Post < ActiveRecord::Base
#   belongs_to :author
#
#   has_many :comments do
#     def find_most_recent
#       order(id: :desc).first
#     end
#
#     def newest
#       created.last
#     end
#
#     def the_association
#       proxy_association
#     end
#
#     def with_content(content)
#       self.detect { |comment| comment.body == content }
#     end
#   end
# end

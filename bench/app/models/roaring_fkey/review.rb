# frozen_string_literal: true

class RoaringFkey::Review < ::RoaringFkey::ApplicationRecord
  belongs_to :book, foreign_key: :roaring_fkey_book_id
  belongs_to :customer, foreign_key: :roaring_fkey_customer_id

  enum state: { not_reviewed: 0,  published: 1,  hidden: 2 } #[:not_reviewed, :published, :hidden]
end

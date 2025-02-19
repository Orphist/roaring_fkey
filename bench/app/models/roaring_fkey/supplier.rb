# frozen_string_literal: true

class RoaringFkey::Supplier < ::RoaringFkey::ApplicationRecord
  belongs_to_many :books, anonymous_class: RoaringFkey::Book, foreign_key: :book_ids, inverse_of: false
  belongs_to_many :authors, anonymous_class: RoaringFkey::Author, foreign_key: :author_ids, inverse_of: false
end

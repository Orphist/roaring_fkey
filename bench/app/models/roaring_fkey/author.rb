# frozen_string_literal: true

class RoaringFkey::Author < ::RoaringFkey::ApplicationRecord
  belongs_to_many :books, anonymous_class: RoaringFkey::Book, foreign_key: :book_ids, inverse_of: false

  def books_count
    book_ids.count
  end
end

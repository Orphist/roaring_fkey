# frozen_string_literal: true

class BookOrder < ApplicationRecord
  self.table_name = 'books_orders'

  belongs_to :book
  belongs_to :order
end

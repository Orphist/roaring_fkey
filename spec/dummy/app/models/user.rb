# frozen_string_literal: true

class User < ApplicationRecord
  has_many :not_logged_posts
end

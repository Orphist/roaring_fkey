# frozen_string_literal: true

class UserGroup < ApplicationRecord
  belongs_to :article, touch: true
end

FactoryBot.define do
  factory :item do
    name { Faker::Lorem.sentence }
    tag_ids { [1] }
  end
end

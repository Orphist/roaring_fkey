FactoryBot.define do
  factory :comment do
    content { Faker::Lorem.paragraph }

    factory :comment_recursive do
      comment_id { UserGroup.order('RANDOM()').first.id }
    end

    trait :random_fakeuser do
      fakeuser_id { Fakeuser.order('RANDOM()').first.id }
    end
  end
end

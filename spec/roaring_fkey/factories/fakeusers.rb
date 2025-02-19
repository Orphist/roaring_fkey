FactoryBot.define do
  factory :fakeuser do
    name { Faker::Name.name }
    role { 'visitor' }
  end
end

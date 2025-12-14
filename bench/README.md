# Performance benchmarks:

Our goal is compare PFK roaringbitmap with classic ActiveRecord Rails associations.

Model schema stolen from https://guides.rubyonrails.org/v8.0/active_record_querying.html

Author.joins(books: [{ reviews: { customer: :orders } }, :supplier])

This is a join table to handle the many-to-many relationship between books and genres. It lists pairs of book and genre IDs.

To run this benchmarks, you need to first provision the example Rails app:

```sh
bundle install
RAILS_ENV=bench bundle exec rails db:migrate
```

To run a benchmark, run the corresponding script:

```sh
RAILS_ENV=bench bundle exec ruby benchmarks/analytics_bench.rb
```


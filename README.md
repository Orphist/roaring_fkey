# RoaringFkey

RoaringFkey gives Rails a foreign key via belongs_to_many using roaringbitmap type in Postgresql 
Roaringbitmap type provided by Pg extension https://pgxn.org/dist/pg_roaringbitmap/

## Limitations
Roaringbitmap type provided by Pg extension supports id::int/uint32 only no bigint
This limitation is due to the pg_roaringbitmap extension wich implemented with uint32 fkey representation. 

## Installation

Add the following to your Gemfile:

```ruby
gem 'roaring_fkey'
````

## Usage

```bash
rails generate roaring_fkey AddKeys
```

This will create a migration named AddKeys which will have `add_foreign_key`
statements for belongs_to_many foreign keys. RoaringFkey infers missing ones by
evaluating the association belongs_to_many in your models.
Only missing keys will be added; existing ones will never be altered or
removed.

## [Changelog](CHANGELOG.md)

## License

Copyright (c) 2024-2025 Orphist, released under the MIT license

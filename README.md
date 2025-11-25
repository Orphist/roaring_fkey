# RoaringFkey

RoaringFkey gives Rails v6+ a foreign key via belongs_to_many using roaringbitmap and roaringbitmap64 types in
Postgresql

Roaringbitmap and roaringbitmap64 types provided by Pg extension https://pgxn.org/dist/pg_roaringbitmap/

## Limitations
Roaringbitmap type provided by Pg extension supports id::int/uint32 only no bigint
This limitation is due to the pg_roaringbitmap extension which implemented with uint32 fkey representation.

Roaringbitmap64 type supports id::bigint/uint64 for larger integer ranges

## Implementation Details

### Function Naming
- **RoaringBitmap**: Uses `rb_build()` function for building bitmaps from integer arrays
- **RoaringBitmap64**: Uses `rb64_build()` function for building bitmaps from bigint arrays

This ensures proper type handling and prevents type casting issues.

## Installation

Add the following to your Gemfile:

```ruby
gem 'roaring_fkey'
````

## Usage

### For standard integer IDs (roaringbitmap)
```bash
rails generate roaring_fkey AddKeys
```

### For bigint IDs (roaringbitmap64)
```bash
rails generate roaring_fkey AddKeys --type=roaringbitmap64
```

This will create a migration named AddKeys which will have `add_foreign_key`
statements for belongs_to_many foreign keys. RoaringFkey infers missing ones by
evaluating the association belongs_to_many in your models.
Only missing keys will be added; existing ones will never be altered or
removed.

### Model Usage

#### For integer IDs (roaringbitmap)
```ruby
class Post < ApplicationRecord
  belongs_to_many :tags  # Uses roaringbitmap for integer IDs
end
```

#### For bigint IDs (roaringbitmap64)
```ruby
class Post < ApplicationRecord
  belongs_to_many :large_tags, class_name: 'Tag', foreign_key: 'large_tag_ids'  # Uses roaringbitmap64 for bigint IDs
end

# Migration
class AddLargeTagIdsToPosts < ActiveRecord::Migration[7.0]
  def change
    add_column :posts, :large_tag_ids, :roaringbitmap64, default: '\x3a3000000100000000000000100000000000'
  end
end
```

## [Changelog](CHANGELOG.md)

## License

Copyright (c) 2024-2026 Orphist, released under the MIT license

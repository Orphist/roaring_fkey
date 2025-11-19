# RoaringBitmap64 Implementation Documentation

## Overview
This document describes the implementation of full support for `roaringbitmap64` (for bitmap of array[bigint]) in the pg_roaringbitmap gem, following the same pattern as `roaringbitmap` (for bitmap of array[int]).

## Key Changes

### 1. Function Naming Convention
- **RoaringBitmap**: Uses `rb_build()` function for building bitmaps from arrays
- **RoaringBitmap64**: Uses `rb64_build()` function for building bitmaps from bigint arrays

This naming convention clearly distinguishes between the two types and ensures proper type handling.

### 2. Implementation Files Modified

#### Core OID Implementation
- **File**: `lib/roaring_fkey/postgresql/adapter/oid/roaringbitmap64.rb`
- **Change**: Line 22 - Changed from `rb_build_array` to `rb64_build`
- **Impact**: Ensures proper bitmap creation for bigint arrays

#### Arel Visitors
- **File**: `lib/roaring_fkey/postgresql/arel/visitors.rb`
- **Changes**: 
  - Added `build_function_for_type()` method to determine correct build function
  - Updated `visit_Arel_Nodes_HomogeneousIn()` to use type-specific build functions
  - Updated `visit_Arel_Nodes_Equality()` to pass type information
  - Updated `visit_Arel_Nodes_NotEqual()` to use type-specific build functions
  - Updated `quote_roaringbiymap()` to accept type parameter
- **Impact**: Proper SQL generation for both bitmap types

#### SQL Functions
- **New File**: `lib/generators/roaring_fkey/install/functions/roaring_fkey_bitmap_overlaps_array_bigint64.sql`
- **Purpose**: Provides roaringbitmap64-specific overlap function using `rb64_build()`
- **Impact**: Enables proper array overlap operations for roaringbitmap64

#### Tests
- **File**: `spec/roaring_fkey/lib/roaringbitmap64_spec.rb`
- **Changes**: 
  - Updated function name expectations to include `roaring_fkey_bitmap_overlaps_array_bigint64`
  - Added test for `rb64_build` function usage
- **Impact**: Ensures proper test coverage for new functionality

## Usage Examples

### Creating Records with RoaringBitmap64
```ruby
# Using ActiveRecord model with roaringbitmap64 field
record = Model.create!(item_ids: [1000000000, 2000000000, 3000000000])
```

### Query Operations
```ruby
# Contains operation
Model.where(item_ids: 1000000000)

# Overlaps operation
Model.where("item_ids && ARRAY[1000000000, 4000000000]::bigint[]")
```

### Direct SQL Usage
```sql
-- Building roaringbitmap64 from bigint array
SELECT rb64_build(ARRAY[1000000000, 2000000000]);

-- Checking overlap
SELECT rb64_build(ARRAY[1, 2, 3]) && rb64_build(ARRAY[2, 3, 4]);
```

## Function Reference

### Build Functions
| Function | Purpose | Type |
|-----------|---------|------|
| `rb_build(ARRAY[...])` | Build roaringbitmap from int array | RoaringBitmap |
| `rb64_build(ARRAY[...])` | Build roaringbitmap64 from bigint array | RoaringBitmap64 |

### Operations
| Operation | RoaringBitmap | RoaringBitmap64 |
|------------|---------------|-----------------|
| Build from array | `rb_build(ARRAY[...])` | `rb64_build(ARRAY[...])` |
| Convert to array | `rb_to_array(bitmap)` | `rb_to_array(bitmap64)` |
| Cardinality | `rb_cardinality(bitmap)` | `rb_cardinality(bitmap64)` |
| Contains | `bitmap @> value` | `bitmap64 @> value` |
| Overlaps | `bitmap && other_bitmap` | `bitmap64 && other_bitmap64` |

## Migration Notes

When upgrading to this version:
1. No database schema changes required
2. Existing roaringbitmap64 columns will continue to work
3. New queries will use `rb64_build()` for better type safety

## Performance Considerations

- `rb64_build()` is optimized for bigint values
- Type-specific functions prevent unnecessary type casting
- Memory usage is optimized for 64-bit integers

## Compatibility

- Requires PostgreSQL with pg_roaringbitmap extension
- Compatible with Rails 6.0+
- Backward compatible with existing roaringbitmap implementations

## Testing

Run the test suite to verify implementation:
```bash
bundle exec rspec spec/roaring_fkey/lib/roaringbitmap64_spec.rb
```

## Troubleshooting

### Common Issues

1. **Function not found**: Ensure pg_roaringbitmap extension is installed
2. **Type errors**: Verify using `rb64_build()` for roaringbitmap64, not `rb_build()`
3. **Performance**: Use appropriate bitmap type for your data size

### Debug Queries
```sql
-- Check if functions are installed
SELECT proname FROM pg_proc WHERE proname LIKE '%roaring%';

-- Test build functions
SELECT rb_build(ARRAY[1, 2, 3]);
SELECT rb64_build(ARRAY[1000000000, 2000000000]);
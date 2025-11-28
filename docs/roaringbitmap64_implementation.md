# RoaringBitmap64 Implementation Documentation

## Overview
This document describes the implementation of full support for `roaringbitmap64` 
(for bitmap of array[bigint]) in the pg_roaringbitmap gem, 
following the same pattern as `roaringbitmap` (for bitmap of array[int]).

## Key Changes

### 1. Function Naming Convention
- **RoaringBitmap**: Uses `rb_...()` function for building bitmaps from arrays
- **RoaringBitmap64**: Uses `rb64_...()` function for building bitmaps from bigint arrays

This naming convention clearly distinguishes between the two types and ensures proper type handling.

### 2. Implementation Files Modified

#### Core OID Implementation
- **File**: `lib/roaring_fkey/postgresql/adapter/oid/roaringbitmap64.rb`

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

## Troubleshooting

### Common Issue

**Function not found**: Ensure pg_roaringbitmap extension is installed

### Debug Queries
```sql
-- Check if functions are installed
SELECT proname FROM pg_proc WHERE proname LIKE '%roaring%';

-- Test build functions
SELECT rb_build(ARRAY[1, 2, 3]);
SELECT rb64_build(ARRAY[1000000000, 2000000000]);
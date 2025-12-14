# Changelog

## 1.0.0

* **Enhancement**: Full support for roaringbitmap64 with rb64_build function
  * Changed roaringbitmap64 OID implementation to use `rb64_build()` instead of `rb_build_array()`
  * Updated Arel visitors to use type-specific build functions (`rb_build()` for roaringbitmap, `rb64_build()` for roaringbitmap64)
  * Added new SQL function `roaring_fkey_bitmap_overlaps_array_bigint64` for roaringbitmap64 array overlap operations
  * Updated tests to verify proper rb64_build usage

## 0.1.0

* Initial release

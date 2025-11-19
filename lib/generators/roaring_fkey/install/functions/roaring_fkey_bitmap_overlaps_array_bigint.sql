do $pl$
begin

  CREATE FUNCTION roaring_fkey_bitmap_overlaps_array_bigint(roaringbitmap, bigint[])
  returns boolean language sql immutable as $$
    SELECT $1 && (rb_build($2))
  $$;

  CREATE OPERATOR && (leftarg = roaringbitmap64, rightarg = bigint[],
      procedure = roaring_fkey_bitmap_overlaps_array_bigint,
      commutator = &&);

exception
    when duplicate_function then
         null;
    when others then
      raise notice E'Got exception: func roaring_fkey_bitmap_overlaps_array_bigint';

end; $pl$;
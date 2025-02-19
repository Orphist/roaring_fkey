do $pl$
begin

  CREATE FUNCTION roaring_fkey_bitmap_contains_bigint(roaringbitmap, bigint)
  returns boolean language sql immutable as $$
    SELECT $1 @> $2::int
  $$;

  CREATE OPERATOR = (leftarg = roaringbitmap, rightarg = bigint,
      procedure = roaring_fkey_bitmap_contains_bigint,
      commutator = =);

exception
    when duplicate_function then
         null;
    when others then
      raise notice E'Got exception: func roaring_fkey_bitmap_contains_bigint';

end; $pl$;

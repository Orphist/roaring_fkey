do $pl$
begin

  CREATE FUNCTION roaring_fkey_bigint_contains_in_bitmap(bigint, roaringbitmap)
  returns boolean language sql immutable as $$
    SELECT $2 @> $1::int
  $$;

  CREATE OPERATOR == (leftarg = bigint, rightarg = roaringbitmap,
      procedure = roaring_fkey_bigint_contains_in_bitmap,
      commutator = =);

exception
    when duplicate_function then
         null;
    when others then
      raise notice E'Got exception: func roaring_fkey_bigint_contains_in_bitmap';
end; $pl$;
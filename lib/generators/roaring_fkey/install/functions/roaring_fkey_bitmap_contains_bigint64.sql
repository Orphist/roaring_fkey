do $pl$
begin

  CREATE FUNCTION roaring_fkey_bitmap_contains_bigint64(roaringbitmap64, bigint)
  returns boolean language sql immutable as $$
    SELECT $1 @> $2
  $$;

  CREATE OPERATOR = (leftarg = roaringbitmap64, rightarg = bigint,
      procedure = roaring_fkey_bitmap_contains_bigint64,
      commutator = =);

exception
    when duplicate_function then
         null;
    when others then
      raise notice E'Got exception: func roaring_fkey_bitmap_contains_bigint64';

end; $pl$;
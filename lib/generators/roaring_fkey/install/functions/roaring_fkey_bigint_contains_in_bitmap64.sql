do $pl$
begin

  CREATE FUNCTION roaring_fkey_bigint_contains_in_bitmap64(bigint, roaringbitmap64)
  returns boolean language sql immutable as $$
    SELECT $2 @> $1
  $$;

  CREATE OPERATOR == (leftarg = bigint, rightarg = roaringbitmap64,
      procedure = roaring_fkey_bigint_contains_in_bitmap64,
      commutator = =);

exception
    when duplicate_function then
         null;
    when others then
      raise notice E'Got exception: func roaring_fkey_bigint_contains_in_bitmap64';

end; $pl$;
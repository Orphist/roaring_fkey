do $pl$
begin

  CREATE FUNCTION roaring_fkey_int_contains_in_bitmap(integer, roaringbitmap)
  returns boolean language sql immutable as $$
    SELECT $2 @> $1
  $$;

  CREATE OPERATOR == (leftarg = integer, rightarg = roaringbitmap,
      procedure = roaring_fkey_int_contains_in_bitmap,
      commutator = =);

exception
    when duplicate_function then
         null;
    when others then
      raise notice E'Got exception: func roaring_fkey_int_contains_in_bitmap';

end; $pl$;

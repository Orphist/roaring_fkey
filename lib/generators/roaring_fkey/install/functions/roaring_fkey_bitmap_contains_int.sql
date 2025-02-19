do $pl$
begin

  CREATE FUNCTION roaring_fkey_bitmap_contains_int(roaringbitmap, integer)
  returns boolean language sql immutable as $$
    SELECT ($1 @> $2)
  $$;

  CREATE OPERATOR = (leftarg = roaringbitmap, rightarg = integer,
      procedure = roaring_fkey_bitmap_contains_int,
      commutator = =);

exception
    when duplicate_function then
         null;
    when others then
      raise notice E'Got exception: func roaring_fkey_bitmap_contains_int';

end; $pl$;

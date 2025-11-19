do $pl$
begin

  CREATE FUNCTION roaring_fkey_bitmap64_count(bigint, roaringbitmap64)
  returns bigint language sql immutable as $$
    SELECT $1+rb64_cardinality($2)
  $$;

  CREATE aggregate count (roaringbitmap64) (
      sfunc = roaring_fkey_bitmap64_count,
      stype = bigint,
      initcond = 0
  );
  --alter aggregate count (roaringbitmap64) owner to postgres;

exception
    when duplicate_function then
         null;
    when others then
      raise notice E'Got exception: roaring_fkey func roaring_bitmap64_count(roaringbitmap64)';

end; $pl$;
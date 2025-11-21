do $pl$
begin

  CREATE FUNCTION roaring_fkey_bitmap64_max(bigint, roaringbitmap64)
  returns bigint language sql immutable as $$
    SELECT GREATEST($1, rb64_max($2))
  $$;

  CREATE aggregate max (roaringbitmap64) (
      sfunc = roaring_fkey_bitmap64_max,
      stype = bigint,
      initcond = 0
  );
  --alter aggregate max (roaringbitmap64) owner to postgres;

exception
    when duplicate_function then
         null;
    when others then
      raise notice E'Got exception: roaring_fkey func roaring_bitmap64_max(roaringbitmap64)';

end; $pl$;
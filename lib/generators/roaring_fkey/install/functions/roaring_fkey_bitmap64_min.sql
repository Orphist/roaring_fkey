do $pl$
begin

  CREATE FUNCTION roaring_fkey_bitmap64_min(bigint, roaringbitmap64)
  returns bigint language sql immutable as $$
    SELECT LEAST($1, rb64_min($2))
  $$;

  CREATE aggregate min (roaringbitmap64) (
      sfunc = roaring_fkey_bitmap64_min,
      stype = bigint,
      initcond = 0
  );
  --alter aggregate min (roaringbitmap64) owner to postgres;

exception
    when duplicate_function then
         null;
    when others then
      raise notice E'Got exception: roaring_fkey func roaringbitmap64_min(roaringbitmap64)';

end; $pl$;
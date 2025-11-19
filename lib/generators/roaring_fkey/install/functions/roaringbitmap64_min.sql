do $pl$
begin

  CREATE FUNCTION roaringbitmap64_min(integer, roaringbitmap64)
  returns int language sql immutable as $$
    SELECT LEAST($1, rb_min($2))
  $$;

  CREATE aggregate min (roaringbitmap64) (
      sfunc = roaringbitmap64_min,
      stype = integer,
      initcond = 0
  );
  --alter aggregate min (roaringbitmap64) owner to postgres;

exception
    when duplicate_function then
         null;
    when others then
      raise notice E'Got exception: roaring_fkey func roaringbitmap64_min(roaringbitmap64)';

end; $pl$;
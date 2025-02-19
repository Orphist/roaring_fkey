do $pl$
begin

  CREATE FUNCTION roaringbitmap_min(integer, roaringbitmap)
  returns int language sql immutable as $$
    SELECT LEAST($1, rb_max($2))
  $$;

  CREATE aggregate min (roaringbitmap) (
      sfunc = roaringbitmap_min,
      stype = integer,
      initcond = 0
  );
  --alter aggregate min (roaringbitmap) owner to postgres;

exception
    when duplicate_function then
         null;
    when others then
      raise notice E'Got exception: roaring_fkey func roaringbitmap_min(roaringbitmap)';

end; $pl$;
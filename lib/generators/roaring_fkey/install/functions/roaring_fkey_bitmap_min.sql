do $pl$
begin

  CREATE FUNCTION roaring_fkey_bitmap_min(integer, roaringbitmap)
  returns int language sql immutable as $$
    SELECT LEAST($1, rb_max($2))
  $$;

  CREATE aggregate min (roaringbitmap) (
      sfunc = roaring_fkey_bitmap_min,
      stype = integer,
      initcond = 0
  );
  --alter aggregate min (roaringbitmap) owner to postgres;

exception
    when duplicate_function then
         null;
    when others then
      raise notice E'Got exception: roaring_fkey func roaring_bitmap_min(roaringbitmap)';

end; $pl$;
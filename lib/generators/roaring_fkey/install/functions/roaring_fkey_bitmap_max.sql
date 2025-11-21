do $pl$
begin

  CREATE FUNCTION roaring_fkey_bitmap_max(integer, roaringbitmap)
  returns int language sql immutable as $$
    SELECT GREATEST($1, rb_max($2))
  $$;

  CREATE aggregate max (roaringbitmap) (
      sfunc = roaring_fkey_bitmap_max,
      stype = integer,
      initcond = 0
  );
  --alter aggregate max (roaringbitmap) owner to postgres;

exception
    when duplicate_function then
         null;
    when others then
      raise notice E'Got exception: roaring_fkey func roaring_bitmap_max(roaringbitmap)';

end; $pl$;
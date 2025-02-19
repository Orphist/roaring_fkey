do $pl$
begin

  CREATE FUNCTION roaringbitmap_count(integer, roaringbitmap)
  returns int language sql immutable as $$
    SELECT $1+rb_cardinality($2)
  $$;

  CREATE aggregate count (roaringbitmap) (
      sfunc = roaringbitmap_count,
      stype = integer,
      initcond = 0
  );
  --alter aggregate count (roaringbitmap) owner to postgres;

exception
    when duplicate_function then
         null;
    when others then
      raise notice E'Got exception: roaring_fkey func roaringbitmap_count(roaringbitmap)';

end; $pl$;
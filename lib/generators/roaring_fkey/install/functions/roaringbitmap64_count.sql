do $pl$
begin

  CREATE FUNCTION roaringbitmap64_count(integer, roaringbitmap64)
  returns int language sql immutable as $$
    SELECT $1+rb_cardinality($2)
  $$;

  CREATE aggregate count (roaringbitmap64) (
      sfunc = roaringbitmap64_count,
      stype = integer,
      initcond = 0
  );
  --alter aggregate count (roaringbitmap64) owner to postgres;

exception
    when duplicate_function then
         null;
    when others then
      raise notice E'Got exception: roaring_fkey func roaringbitmap64_count(roaringbitmap64)';

end; $pl$;
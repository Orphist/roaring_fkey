do $pl$
begin

  CREATE FUNCTION roaringbitmap64_max(integer, roaringbitmap64)
  returns int language sql immutable as $$
    SELECT GREATEST($1, rb_max($2))
  $$;

  CREATE aggregate max (roaringbitmap64) (
      sfunc = roaringbitmap64_max,
      stype = integer,
      initcond = 0
  );
  --alter aggregate max (roaringbitmap64) owner to postgres;

exception
    when duplicate_function then
         null;
    when others then
      raise notice E'Got exception: roaring_fkey func roaringbitmap64_max(roaringbitmap64)';

end; $pl$;
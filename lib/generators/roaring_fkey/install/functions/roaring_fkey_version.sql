do $pl$
begin
  CREATE FUNCTION roaring_fkey_version()
    returns int language sql immutable as $$
        SELECT <%= roaring_fkey_version %>
  $$;
exception
    when duplicate_function then
         null;
    when others then
      raise notice E'Got exception: func roaring_fkey_version';

end; $pl$;

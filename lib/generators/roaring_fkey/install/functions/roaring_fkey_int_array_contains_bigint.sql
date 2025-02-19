do $pl$
begin

  CREATE FUNCTION roaring_fkey_int_array_contains_bigint(integer[], bigint)
  returns boolean language sql immutable as $$
    SELECT $2::int = ANY($1)
  $$;

  CREATE OPERATOR = (leftarg = integer[], rightarg = bigint,
      procedure = roaring_fkey_int_array_contains_bigint,
      commutator = =);

exception
    when duplicate_function then
         null;
    when others then
      raise notice E'Got exception: func roaring_fkey_int_array_contains_bigint';

end; $pl$;

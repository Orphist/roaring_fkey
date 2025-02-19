do $pl$
begin

  CREATE FUNCTION roaring_fkey_bigint_contains_int_array(bigint, integer[])
  returns boolean language sql immutable as $$
    SELECT $1::int = ANY($2)
  $$;

  CREATE OPERATOR = (leftarg = bigint, rightarg = integer[],
      procedure = roaring_fkey_bigint_contains_int_array,
      commutator = =);

exception
    when duplicate_function then
         null;
    when others then
      raise notice E'Got exception: func roaring_fkey_bigint_contains_int_array';

end; $pl$;

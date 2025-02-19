class RoaringFkeyInstall < ActiveRecord::Migration[6.1]
  def up
    execute <<~SQL
      DROP FUNCTION IF EXISTS roaring_fkey_bigint_contains_in_bitmap(bigint, roaringbitmap) CASCADE;
      DROP FUNCTION IF EXISTS roaring_fkey_bigint_contains_int_array(bigint, integer[]) CASCADE;
      DROP FUNCTION IF EXISTS roaring_fkey_bigint_eq_int_array(bigint, integer[]) CASCADE;
      DROP FUNCTION IF EXISTS roaring_fkey_bitmap_contains_bigint(roaringbitmap, bigint) CASCADE;
      DROP FUNCTION IF EXISTS roaring_fkey_bitmap_contains_int(roaringbitmap, integer) CASCADE;
      DROP FUNCTION IF EXISTS roaring_fkey_bitmap_overlaps_array_int(roaringbitmap, integer[]) CASCADE;
      DROP FUNCTION IF EXISTS roaring_fkey_int_array_contains_bigint(integer[], bigint) CASCADE;
      DROP FUNCTION IF EXISTS roaring_fkey_int_contains_in_bitmap(integer, roaringbitmap) CASCADE;
      DROP FUNCTION IF EXISTS roaring_fkey_version() CASCADE;
      DROP FUNCTION IF EXISTS roaringbitmap_count(integer, roaringbitmap) CASCADE;
      DROP FUNCTION IF EXISTS roaringbitmap_max(integer, roaringbitmap) CASCADE;
      DROP FUNCTION IF EXISTS roaringbitmap_min(integer, roaringbitmap) CASCADE;
    SQL

    execute <<~SQL
      do $pl$
      begin

        CREATE FUNCTION roaring_fkey_bigint_contains_in_bitmap(bigint, roaringbitmap)
        returns boolean language sql immutable as $$
          SELECT $2 @> $1::int
        $$;

        CREATE OPERATOR == (leftarg = bigint, rightarg = roaringbitmap,
            procedure = roaring_fkey_bigint_contains_in_bitmap,
            commutator = =);

      exception
          when duplicate_function then
               null;
          when others then
            raise notice E'Got exception: func roaring_fkey_bigint_contains_in_bitmap';
      end; $pl$;
    SQL
    execute <<~SQL
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

    SQL
    execute <<~SQL
      do $pl$
      begin

        CREATE FUNCTION roaring_fkey_bigint_eq_int_array(bigint, integer[])
        returns boolean language sql immutable as $$
          SELECT $1::int = ANY($2);
        $$;

        CREATE OPERATOR == (leftarg = bigint, rightarg = integer[],
            procedure = roaring_fkey_bigint_eq_int_array,
            commutator = =);

      exception
          when duplicate_function then
               null;
          when others then
            raise notice E'Got exception: func roaring_fkey_bigint_eq_int_array';

      end; $pl$;

    SQL
    execute <<~SQL
      do $pl$
      begin

        CREATE FUNCTION roaring_fkey_bitmap_contains_bigint(roaringbitmap, bigint)
        returns boolean language sql immutable as $$
          SELECT $1 @> $2::int
        $$;

        CREATE OPERATOR = (leftarg = roaringbitmap, rightarg = bigint,
            procedure = roaring_fkey_bitmap_contains_bigint,
            commutator = =);

      exception
          when duplicate_function then
               null;
          when others then
            raise notice E'Got exception: func roaring_fkey_bitmap_contains_bigint';

      end; $pl$;

    SQL
    execute <<~SQL
      do $pl$
      begin

        CREATE FUNCTION roaring_fkey_bitmap_contains_int(roaringbitmap, integer)
        returns boolean language sql immutable as $$
          SELECT ($1 @> $2)
        $$;

        CREATE OPERATOR = (leftarg = roaringbitmap, rightarg = integer,
            procedure = roaring_fkey_bitmap_contains_int,
            commutator = =);

      exception
          when duplicate_function then
               null;
          when others then
            raise notice E'Got exception: func roaring_fkey_bitmap_contains_int';

      end; $pl$;

    SQL
    execute <<~SQL
      do $pl$
      begin

        CREATE FUNCTION roaring_fkey_bitmap_overlaps_array_int(roaringbitmap, integer[])
        returns boolean language sql immutable as $$
          SELECT $1 && (rb_build($2));
        $$;

        CREATE OPERATOR && (leftarg = roaringbitmap, rightarg = integer[],
            procedure = roaring_fkey_bitmap_overlaps_array_int,
            commutator = &&);

      exception
          when duplicate_function then
               null;
          when others then
            raise notice E'Got exception: func roaring_fkey_bitmap_overlaps_array_int';

      end; $pl$;

    SQL
    execute <<~SQL
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

    SQL
    execute <<~SQL
      do $pl$
      begin

        CREATE FUNCTION roaring_fkey_int_contains_in_bitmap(integer, roaringbitmap)
        returns boolean language sql immutable as $$
          SELECT $2 @> $1
        $$;

        CREATE OPERATOR == (leftarg = integer, rightarg = roaringbitmap,
            procedure = roaring_fkey_int_contains_in_bitmap,
            commutator = =);

      exception
          when duplicate_function then
               null;
          when others then
            raise notice E'Got exception: func roaring_fkey_int_contains_in_bitmap';

      end; $pl$;

    SQL
    execute <<~SQL
      do $pl$
      begin
        CREATE FUNCTION roaring_fkey_version()
          returns int language sql immutable as $$
              SELECT 0233
        $$;
      exception
          when duplicate_function then
               null;
          when others then
            raise notice E'Got exception: func roaring_fkey_version';

      end; $pl$;

    SQL
    execute <<~SQL
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
            raise notice E'Got exception: roaring_fkey func count(roaringbitmap)';

      end; $pl$;

    SQL
    execute <<~SQL
      do $pl$
      begin

        CREATE FUNCTION roaringbitmap_max(integer, roaringbitmap)
        returns int language sql immutable as $$
          SELECT GREATEST($1, rb_max($2))
        $$;

        CREATE aggregate max (roaringbitmap) (
            sfunc = roaringbitmap_max,
            stype = integer,
            initcond = 0
        );
        --alter aggregate max (roaringbitmap) owner to postgres;

      exception
          when duplicate_function then
               null;
          when others then
            raise notice E'Got exception: roaring_fkey func roaringbitmap_max(roaringbitmap)';

      end; $pl$;
    SQL
    execute <<~SQL
      do $pl$
      begin

        CREATE FUNCTION roaringbitmap_min(integer, roaringbitmap)
        returns int language sql immutable as $$
          SELECT GREATEST($1, rb_max($2))
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
    SQL
  end

  def down
    execute <<~SQL
      DROP FUNCTION IF EXISTS roaring_fkey_bigint_contains_in_bitmap(bigint, roaringbitmap) CASCADE;
      DROP FUNCTION IF EXISTS roaring_fkey_bigint_contains_int_array(bigint, integer[]) CASCADE;
      DROP FUNCTION IF EXISTS roaring_fkey_bigint_eq_int_array(bigint, integer[]) CASCADE;
      DROP FUNCTION IF EXISTS roaring_fkey_bitmap_contains_bigint(roaringbitmap, bigint) CASCADE;
      DROP FUNCTION IF EXISTS roaring_fkey_bitmap_contains_int(roaringbitmap, integer) CASCADE;
      DROP FUNCTION IF EXISTS roaring_fkey_bitmap_overlaps_array_int(roaringbitmap, integer[]) CASCADE;
      DROP FUNCTION IF EXISTS roaring_fkey_int_array_contains_bigint(integer[], bigint) CASCADE;
      DROP FUNCTION IF EXISTS roaring_fkey_int_contains_in_bitmap(integer, roaringbitmap) CASCADE;
      DROP FUNCTION IF EXISTS roaring_fkey_version() CASCADE;
      DROP FUNCTION IF EXISTS roaringbitmap_count(integer, roaringbitmap) CASCADE;
      DROP FUNCTION IF EXISTS roaringbitmap_max(integer, roaringbitmap) CASCADE;
      DROP FUNCTION IF EXISTS roaringbitmap_min(integer, roaringbitmap) CASCADE;
    SQL
  end
end

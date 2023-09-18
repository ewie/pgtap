CREATE FUNCTION parse_type(type text, OUT typid oid, OUT typmod int4)
RETURNS RECORD
AS '$libdir/pgtap'
LANGUAGE C STABLE STRICT;

CREATE OR REPLACE FUNCTION format_type_string ( TEXT )
RETURNS TEXT AS $$
BEGIN RETURN format_type(p.typid, p.typmod) from parse_type($1) p;
EXCEPTION WHEN OTHERS THEN RETURN NULL;
END;
$$ LANGUAGE PLPGSQL STABLE;

-- col_type_is( schema, table, column, schema, type, description )
CREATE OR REPLACE FUNCTION col_type_is ( NAME, NAME, NAME, NAME, TEXT, TEXT )
RETURNS TEXT AS $$
DECLARE
    have_type TEXT := _get_col_ns_type($1, $2, $3);
    want_type TEXT;
BEGIN
    IF have_type IS NULL THEN
        RETURN fail( $6 ) || E'\n' || diag (
            '   Column ' || COALESCE(quote_ident($1) || '.', '')
            || quote_ident($2) || '.' || quote_ident($3) || ' does not exist'
        );
    END IF;

    IF quote_ident($4) = ANY(current_schemas(true)) THEN
        want_type := quote_ident($4) || '.' || format_type_string($5);
    ELSE
        want_type := format_type_string(quote_ident($4) || '.' || $5);
    END IF;

    IF want_type IS NULL THEN
        RETURN fail( $6 ) || E'\n' || diag (
            '    Type ' || quote_ident($4) || '.' || $5 || ' does not exist'
        );
    END IF;

    IF have_type = want_type THEN
        -- We're good to go.
        RETURN ok( true, $6 );
    END IF;

    -- Wrong data type. tell 'em what we really got.
    RETURN ok( false, $6 ) || E'\n' || diag(
           '        have: ' || have_type ||
        E'\n        want: ' || want_type
    );
END;
$$ LANGUAGE plpgsql;

-- col_type_is( schema, table, column, schema, type )
CREATE OR REPLACE FUNCTION col_type_is ( NAME, NAME, NAME, NAME, TEXT )
RETURNS TEXT AS $$
    SELECT col_type_is( $1, $2, $3, $4, $5, 'Column ' || quote_ident($1) || '.' || quote_ident($2)
        || '.' || quote_ident($3) || ' should be type ' || quote_ident($4) || '.' || $5);
$$ LANGUAGE SQL;

-- col_type_is( schema, table, column, type, description )
CREATE OR REPLACE FUNCTION col_type_is ( NAME, NAME, NAME, TEXT, TEXT )
RETURNS TEXT AS $$
DECLARE
    have_type TEXT;
    want_type TEXT;
BEGIN
    -- Get the data type.
    IF $1 IS NULL THEN
        have_type := _get_col_type($2, $3);
    ELSE
        have_type := _get_col_type($1, $2, $3);
    END IF;

    IF have_type IS NULL THEN
        RETURN fail( $5 ) || E'\n' || diag (
            '   Column ' || COALESCE(quote_ident($1) || '.', '')
            || quote_ident($2) || '.' || quote_ident($3) || ' does not exist'
        );
    END IF;

    want_type := format_type_string($4);
    IF want_type IS NULL THEN
        RETURN fail( $5 ) || E'\n' || diag (
            '    Type ' || $4 || ' does not exist'
        );
    END IF;

    IF have_type = want_type THEN
        -- We're good to go.
        RETURN ok( true, $5 );
    END IF;

    -- Wrong data type. tell 'em what we really got.
    RETURN ok( false, $5 ) || E'\n' || diag(
           '        have: ' || have_type ||
        E'\n        want: ' || want_type
    );
END;
$$ LANGUAGE plpgsql;

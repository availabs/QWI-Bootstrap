SELECT COUNT(*)
FROM   pg_catalog.pg_class c
JOIN   pg_catalog.pg_namespace n ON n.oid = c.relnamespace
WHERE  n.nspname = 'public'
AND    c.relname = '__TABLE_NAME__'
AND    c.relkind = 'r'    -- only tables(?);

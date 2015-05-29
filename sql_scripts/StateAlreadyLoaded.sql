SELECT EXISTS(
    SELECT 1
    FROM   __TABLE_NAME__ 
    WHERE  geography = (
        SELECT substring(geography from 1 for 2)
        FROM label_geography
        WHERE substring(lower(label) from '..$') = lower('__STATE_ABBR__')
        LIMIT 1
    )
    LIMIT 1
);

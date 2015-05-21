SELECT COUNT(*)
FROM   __TABLE_NAME__
WHERE  geography = (
    SELECT DISTINCT state_fips_code FROM fips_codes WHERE LOWER(state_abbreviation) = LOWER('__STATE_ABBR__')
);

DROP TABLE IF EXISTS fips_codes;

CREATE TABLE fips_codes (
    State_Abbreviation  char(2),
    State_FIPS_Code     char(2),
    County_FIPS_Code    char(3),
    FIPS_Entity_Code    char(5),
    ANSI_Code           char(8),
    GU_Name             varchar, 
    Entity_Description  varchar
);

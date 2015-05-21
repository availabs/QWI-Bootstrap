#!/bin/bash

set -e

## Code Mappings taken from:
#wget http://www.census.gov/2010census/xls/fips_codes_website.xls ;

## Convert xls to csv
#echo "Convert the xls file to csv."
#ssconvert fips_codes_website.xls fips_codes.csv ;

## Remove the xls file
#rm -f fips_codes_website.xls ;

# Create the fips table.
echo "Creating the fips table."
cat CREATE-fips_codes-TABLE.sql | psql -U qwi_api -d qwi ;

echo "Loading the data into the database."
sed "s/__PWD__/$(pwd | sed 's/\//\\\//g')/g" LoadData.sql | psql -U qwi_api -d qwi ;


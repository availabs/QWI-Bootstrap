#!/bin/bash

### !!! This code has yet to be run after major refactoring. !!! ###

echo "Get Column Definitions" 
wget -O column_definitions.txt "http://lehd.ces.census.gov/php/inc_download.php?s=ny&f=/R2014Q4/DVD-sa_f/column_definitions.txt"
echo

echo "Initialize the database."
mkdir -p /home/paul/opt/postgres/data
initdb -D /home/paul/opt/postgres/data/QWI

echo "Starting up Postgres in background."
postgres -D /home/paul/opt/postgres/data/QWI/ & 
echo 

echo "Creating the QWI database."
createdb qwi;\
cat CREATE_TABLE_QWI.sql | psql -U paul -d qwi
echo 

echo "Creating the SELECT only qwi_api user"
echo "CREATE USER qwi_api;" | psql -U paul -d qwi 
echo "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO qwi_api;" | psql -U paul -d qwi
echo "GRANT SELECT ON ALL TABLES IN SCHEMA public TO qwi_api;" | psql -U paul -d qwi
echo 

echo "Shutting  down the database server."
kill -INT `head -1 ~/opt/postgres/data/QWI/postmaster.pid`
echo

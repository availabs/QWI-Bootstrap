POSTGRES_USER="paul"

cat ./sql_scripts/CREATE-qwi_api-USER.sql | psql -U ${POSTGRES_USER} -q -d qwi 

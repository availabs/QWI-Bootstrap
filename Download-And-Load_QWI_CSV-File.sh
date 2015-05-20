#!/bin/bash

# NYS QWI Aggregation Combinations
#
#   qwi_ny_sa_fa_gc_ns_op_u
#   qwi_ny_sa_fa_gm_ns_op_u
#   qwi_ny_sa_fa_gs_n3_op_u
#   qwi_ny_sa_fa_gs_n4_op_u
#   qwi_ny_sa_fa_gs_ns_op_u
#   qwi_ny_sa_fa_gw_ns_op_u

set -e

QWI_VERSION='R2015Q2'

STATE='ny'

QWI_FILE_NAME="qwi_${STATE}_sa_fa_gm_ns_op_u"
QWI_FILE_CSV="${QWI_FILE_NAME}.csv"
QWI_FILE_GZ="${QWI_FILE_CSV}.gz"

QWI_DATA_ADDR="http://lehd.ces.census.gov/pub/${STATE}/${QWI_VERSION}/DVD-sa_fa/${QWI_FILE_GZ}"


LOAD_DATA_COMMAND="\copy qwi FROM '${PWD}/${QWI_FILE_CSV}' DELIMITER ',' CSV HEADER;"


echo "Downloading the ${QWI_FILE_NAME} dataset."
wget ${QWI_DATA_ADDR}
echo 

echo "Inflating the ${QWI_FILE_NAME} dataset."
gunzip ${QWI_FILE_GZ}
echo 

echo "Deleting ${QWI_FILE_GZ}."
rm -f ${QWI_FILE_GZ}
echo 

echo "Loading the ${QWI_FILE_NAME} dataset into the database."
echo ${LOAD_DATA_COMMAND} | psql -U qwi_api -d qwi


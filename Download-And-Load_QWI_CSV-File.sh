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

if [[ -z $(ps -A | grep 'postgres') ]];
then
    echo "Postgres must be running."
    exit
fi

QWI_VERSION='R2015Q1'

#STATES=( 'ny' 'nj' )
#WORKER_CHARACTERISTICS=( 'rh' 'sa' 'se' )
#FIRM_CHARACTERISTICS=( 'fa' 'fs' )
#DATA_AGGREGATIONS=( 'gc_ns_op_u' 'gm_ns_op_u' 'gs_n3_op_u' 'gs_n4_op_u' 'gs_ns_op_u' 'gw_ns_op_u' )

STATES=( 'ny' 'nj' )
WORKER_CHARACTERISTICS=( 'se' )
FIRM_CHARACTERISTICS=( 'fa' )
DATA_AGGREGATIONS=( 'gw_ns_op_u' )

for state in "${STATES[@]}"
do
    for worker_characteristic in "${WORKER_CHARACTERISTICS[@]}"
    do
        for firm_characteristic in "${FIRM_CHARACTERISTICS[@]}"
        do
            for aggregation in "${DATA_AGGREGATIONS[@]}"
            do
                TABLE_NAME="${worker_characteristic}_${firm_characteristic}_${aggregation}"

                QWI_FILE_NAME="qwi_${state}_${TABLE_NAME}"
                QWI_FILE_CSV="${QWI_FILE_NAME}.csv"
                QWI_FILE_GZ="${QWI_FILE_CSV}.gz"
                QWI_FILE_TAR="./downloaded_data/${QWI_FILE_CSV}.tar.gz"

                LOAD_DATA_COMMAND="\copy ${TABLE_NAME} FROM '${PWD}/${QWI_FILE_CSV}' DELIMITER ',' CSV HEADER;"

                QWI_DATA_ADDR="http://lehd.ces.census.gov/pub/${state}/${QWI_VERSION}/DVD-${worker_characteristic}_${firm_characteristic}/${QWI_FILE_GZ}"

                echo
                echo "#########################################################################################"
                echo

                ######################################################
                #
                # If the table does not exist, create it.
                #
                TABLE_COUNT=$(sed "s/__TABLE_NAME__/${TABLE_NAME}/g" ./sql_scripts/TableExistenceCheck.sql | psql qwi)
                TABLE_COUNT=$(echo "${TABLE_COUNT//[[:blank:]]/}" | sed -n 3p) 

                if [[ ${TABLE_COUNT} == '0' ]];  
                then 
                    echo "Creating table ${TABLE_NAME}."
                    sed "s/__TABLE_NAME__/${TABLE_NAME}/g" ./sql_scripts/CREATE_QWI_TABLE.sql | psql qwi
                else
                    # Because duplicate rows are bad...
                    SQL_SCRIPT=$(sed "s/__TABLE_NAME__/${TABLE_NAME}/g" ./sql_scripts/StateAlreadyLoaded.sql)
                    SQL_SCRIPT=$(echo ${SQL_SCRIPT} | sed "s/__STATE_ABBR__/${state}/g")

                    STATE_COUNT_IN_TABLE=$(echo ${SQL_SCRIPT} | psql qwi)
                    STATE_COUNT_IN_TABLE=$(echo "${STATE_COUNT_IN_TABLE//[[:blank:]]/}" | sed -n 3p) 

                    if [[ ${STATE_COUNT_IN_TABLE} == '0' ]];
                    then
                        echo "Inserting ${state} into existing table, ${TABLE_NAME}."
                    else
                        echo "ERROR: ${state} already in ${TABLE_NAME}."
                        echo "       Skipping this state for this table."
                        continue
                    fi
                fi

                # Is the csv already in the downloaded_data directory?
                if [ -f ${QWI_FILE_TAR} ];
                then
                    echo "Using a local archived version of ${QWI_FILE_NAME}."
                    tar zxvf ${QWI_FILE_TAR} -C $(pwd)
                else
                    echo "downloading the ${QWI_FILE_NAME} csv."
                    wget ${QWI_DATA_ADDR}
                    echo 

                    echo "inflating the ${QWI_FILE_NAME} csv."
                    gunzip ${QWI_FILE_GZ}
                    echo 
                fi

                echo "loading the ${QWI_FILE_NAME} dataset into the database."
                echo "${LOAD_DATA_COMMAND}" | psql -U qwi_api -d qwi
                echo 

                if [ ! -f ${QWI_FILE_TAR} ];
                then
                    echo "moving tarball of ${QWI_FILE_CSV} to ./downloaded_data/"
                    tar zcvf "${QWI_FILE_TAR}" "${QWI_FILE_CSV}"
                    echo 
                fi

                echo "deleting ${QWI_FILE_CSV}."
                rm -f ${QWI_FILE_CSV}
                echo 

            done
        done
    done
done


#!/bin/bash


set -e

if [[ -z $(ps -A | grep 'postgres') ]];
then
    echo "Postgres must be running."
    exit
fi


CENSUS_GOV_SITE="http://lehd.ces.census.gov/pub"

# !!! If you are changing the following variable's value, 
# !!! Make sure to DROP all the db tables and rm-rf the downloaded data dir.
QWI_RELEASE='R2015Q1' 

LABELS_DIR="./labels"
GEO_LABELS_DIR="${PWD}/${LABELS_DIR}/${QWI_RELEASE}/geography"

SQL_SCRIPTS_DIR="./sql_scripts"
CREATE_LABEL_TABLES_SCRIPT="Create-labels-Tables.sh"

#STATES=( 'ny' 'nj' )
#WORKER_CHARACTERISTICS=( 'rh' 'sa' 'se' )
#FIRM_CHARACTERISTICS=( 'fa' 'fs' )
#DATA_AGGREGATIONS=( 'gc_ns_op_u' 'gm_ns_op_u' 'gs_n3_op_u' 'gs_n4_op_u' 'gs_ns_op_u' 'gw_ns_op_u' )

STATES=( 'ny' 'nj' )
WORKER_CHARACTERISTICS=( 'se' )
FIRM_CHARACTERISTICS=( 'fa' )
DATA_AGGREGATIONS=( 'gm_ns_op_u' 'gc_ns_op_u' )

GENERIC_LABEL_TABLES=(   \
    'label_agegrp'       \
    'label_education'    \
    'label_ethnicity'    \
    'label_firmage'      \
    'label_firmsize'     \
    'label_geo_level'    \
    'label_ind_level'    \
    'label_ownercode'    \
    'label_periodicity'  \
    'label_race'         \
    'label_seasonadj'    \
    'label_sex'          \
);


# For making sure the passed in table name exists in the database.
# PARAM   : table_name
# RETURNS : Count... 1 if there, 0 otherwise
#
function table_count() {
    local TABLE_NAME=$1
    local TABLE_COUNT=$(sed "s/__TABLE_NAME__/${TABLE_NAME}/g" ${SQL_SCRIPTS_DIR}/TableExistenceCheck.sql | psql -q qwi)
    local TABLE_COUNT=$(echo "${TABLE_COUNT//[[:blank:]]/}" | sed -n 3p) 

    echo "${TABLE_COUNT}"
}


# Create the label tables, if necessary.

if [[ ! $(table_count ${GENERIC_LABEL_TABLES}) == '0' ]];  
then 
    echo "Label tables already in database."
    echo "     (Assuming all done label tables created as a batch, and none are empty.)"
    echo
else 
    echo "Creating the label_* tables in the database."
    bash ${CREATE_LABEL_TABLES_SCRIPT}
    echo

    # Make sure ./labels/ directory exists
    if [ ! -d "${LABELS_DIR}/${QWI_RELEASE}" ];
    then
        echo "Creating the ./${LABELS_DIR}/${QWI_RELEASE} directory."
        mkdir -p "${LABELS_DIR}/${QWI_RELEASE}"
    fi

    if [ "$(ls -A ${LABELS_DIR}/${QWI_RELEASE})" ];
    then
        echo "Generic data labels already in ${LABELS_DIR}/${QWI_RELEASE}."
        echo "   (Assuming if one there, then all there.)"
        echo
    else
        echo "Generic data labels not already in ${LABELS_DIR}/${QWI_RELEASE}."
        echo "Downloading the data."
        
        # http://lehd.ces.census.gov/pub/ny/R2015Q1/DVD-se_fa/label_agegrp.csv
        ENDPOINT="${CENSUS_GOV_SITE}/${STATES}/${QWI_RELEASE}/DVD-${WORKER_CHARACTERISTICS}_${FIRM_CHARACTERISTICS}"

        for table in "${GENERIC_LABEL_TABLES[@]}" 
        do
            wget -P "${LABELS_DIR}/${QWI_RELEASE}/" "${ENDPOINT}/${table}.csv"
            echo
        done
    fi

    # Load the data into the tables.
    for table in "${GENERIC_LABEL_TABLES[@]}" 
    do
        echo "Loading the ${table} csv into the table."
        LOAD_DATA_CMD="\copy ${table} FROM '${PWD}/${LABELS_DIR}/${QWI_RELEASE}/${table}.csv' DELIMITER ',' CSV HEADER;"
        echo "${LOAD_DATA_CMD}" | psql -q -U qwi_api -d qwi
    done
fi


# We need to handle the state geography labels differently.
if [ ! -d "${LABELS_DIR}/${QWI_RELEASE}/geography/" ];
then
    echo "Creating the geography labels directory."
    mkdir -p "${GEO_LABELS_DIR}"
fi

for state in "${STATES[@]}"
do
    if [ ! -f "${GEO_LABELS_DIR}/${state}.csv" ];
    then
        echo "Downloading ${state}'s geography labels.'"
        ENDPOINT="${CENSUS_GOV_SITE}/${state}/${QWI_RELEASE}/DVD-${WORKER_CHARACTERISTICS}_${FIRM_CHARACTERISTICS}"
        wget -O "${GEO_LABELS_DIR}/${state}.csv" "${ENDPOINT}/label_geography.csv"
    fi
done


for state in "${STATES[@]}"
do
    for worker_ch in "${WORKER_CHARACTERISTICS[@]}"
    do
        for firm_ch in "${FIRM_CHARACTERISTICS[@]}"
        do
            for aggregation in "${DATA_AGGREGATIONS[@]}"
            do
                TABLE_NAME="${worker_ch}_${firm_ch}_${aggregation}"

                QWI_FILE_NAME="qwi_${state}_${TABLE_NAME}"
                QWI_FILE_CSV="${QWI_FILE_NAME}.csv"
                QWI_FILE_GZ="${QWI_FILE_CSV}.gz"
                QWI_FILE_TAR="./downloaded_data/${QWI_FILE_CSV}.tar.gz"

                QWI_DATA_ADDR="${CENSUS_GOV_SITE}/${state}/${QWI_RELEASE}/DVD-${worker_ch}_${firm_ch}/${QWI_FILE_GZ}"

                echo
                echo "#########################################################################################"
                echo

                ######################################################
                #
                # If the table does not exist, create it.
                #
                TABLE_COUNT=$(sed "s/__TABLE_NAME__/${TABLE_NAME}/g" ${SQL_SCRIPTS_DIR}/TableExistenceCheck.sql | psql -q qwi)
                TABLE_COUNT=$(echo "${TABLE_COUNT//[[:blank:]]/}" | sed -n 3p) 

                if [[ ${TABLE_COUNT} == '0' ]];  
                then 
                    echo "Creating table ${TABLE_NAME}."
                    sed "s/__TABLE_NAME__/${TABLE_NAME}/g" ${SQL_SCRIPTS_DIR}/CREATE_QWI_TABLE.sql | psql -q qwi
                else
                    ## Because duplicate rows are bad...

                    # First, we must make sure that the state is in the labels_geography table.
                    echo "Checking whether ${state} is in the label_geography table."
                    Q="select exists(select 1 from label_geography where substring(lower(label) from '..$')='${state}');"
                    EXISTS="$(echo ${Q} | psql -q -d qwi -t)"
                    if [ ${EXISTS} == 't' ];
                    then
                        echo "${state} is in label_geography."
                    else
                        echo "Loading ${state}'s geography labels into the label_geography table."
                        LOAD_DATA_CMD="\copy label_geography FROM '${GEO_LABELS_DIR}/${state}.csv' DELIMITER ',' CSV HEADER;"
                        echo "${LOAD_DATA_CMD}" | psql -q -U qwi_api -d qwi
                    fi
                    
                    SQL_SCRIPT=$(sed "s/__TABLE_NAME__/${TABLE_NAME}/g" ${SQL_SCRIPTS_DIR}/StateAlreadyLoaded.sql)
                    SQL_SCRIPT=$(echo ${SQL_SCRIPT} | sed "s/__STATE_ABBR__/${state}/g")

                    STATE_COUNT_IN_TABLE=$(echo ${SQL_SCRIPT} | psql -q qwi)
                    STATE_COUNT_IN_TABLE=$(echo "${STATE_COUNT_IN_TABLE//[[:blank:]]/}" | sed -n 3p) 

                    if [[ ${STATE_COUNT_IN_TABLE} == 'f' ]];
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

                LOAD_DATA_CMD="\copy ${TABLE_NAME} FROM '${PWD}/${QWI_FILE_CSV}' DELIMITER ',' CSV HEADER;"
                echo "loading the ${QWI_FILE_NAME} dataset into the database."
                echo "${LOAD_DATA_CMD}" | psql -q -U qwi_api -d qwi
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


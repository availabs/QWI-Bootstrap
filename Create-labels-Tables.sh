#!/bin/bash

TEMPLATE_SCRIPT='./sql_scripts/CREATE-label_TEMPLATE-TABLE.sql'

ATTRIBUTES=(      \
    'agegrp'      \
    'education'   \
    'ethnicity'   \
    'firmage'     \
    'firmsize'    \
    'geo_level'   \
    'geography'   \
    'ind_level'   \
    'industry'    \
    'ownercode'   \
    'periodicity' \
    'race'        \
    'seasonadj'   \
    'sex'         \
);

for attribute in "${ATTRIBUTES[@]}"
do
    cat ${TEMPLATE_SCRIPT} | sed "s/__ATTRIBUTE__/${attribute}/" | psql -q -U qwi_api -d qwi
done

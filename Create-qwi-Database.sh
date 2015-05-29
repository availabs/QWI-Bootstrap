#!/bin/bash

set -e;

POSTGRES_USER="paul"

if [ -z ${POSTGRES_HOME} ]; 
then 
    echo "The environment variable 'POSTGRES_HOME' must be set."
    exit
fi

if [[ -n $(ps -A | grep postgres) ]]; 
then 
    echo "Shutdown postgres before running this script."
    exit
fi

if [ -d "${POSTGRES_HOME}/data/QWI/" ];
then
    #echo "Deleting the old ${POSTGRES_HOME}/data/QWI/ directory."
    rm -rf "${POSTGRES_HOME}/data/QWI/"
fi

#echo "Create the QWI data directory."
mkdir -p ${POSTGRES_HOME}/data
${POSTGRES_HOME}/bin/initdb -D ${POSTGRES_HOME}/data/QWI

#echo "Starting up Postgres in background."
${POSTGRES_HOME}/bin/postgres -D ${POSTGRES_HOME}/data/QWI &
echo 

sleep 5

#echo "Create the qwi database."
${POSTGRES_HOME}/bin/createdb qwi
echo

echo 
echo "Database now running."
echo 

echo "Check the Postgres output above for errors."
echo

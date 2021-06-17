#!/bin/sh

# still to be runned end to end
export WORK_DIR=$(pwd)
export DATA_DIR=$(pwd)/public/data

# get old opendata
mkdir -p ${DATA_DIR}/src
cd ${DATA_DIR}/src
for source in CASS CAPP;do
    curl https://echanges.dila.gouv.fr/OPENDATA/${source}/ | sed 's/.*href="//;s/".*//' | grep gz | sed "s|^|https://echanges.dila.gouv.fr/OPENDATA/${source}/|" | xargs wget;
done;

# detar
mkdir -p ${DATA_DIR}/decisions
cd ${DATA_DIR}/xml
for file in $(find ${DATA_DIR}/src -iname *.gz);do
    tar xzf $file;
done;

# prepare
find ${DATA_DIR}/decisions -iname '*xml' | xargs -P10 -I{} ~/bin/decision_xml_to_json.sh {} {}.json






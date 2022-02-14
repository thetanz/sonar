#!/bin/bash

# fetch the json schema file from rapid 7 for fdns & rdns datasets
# there are two schemas (fdns and rdns) that cater to all datasets we
# fetch within datasets.sh - these two schemas are identical so we just fetch one
# note big query has it's own schema (le sigh) reference the below link for more info
# https://cloud.google.com/bigquery/docs/schemas#creating_a_json_schema_file

set -e

project_dir=`git rev-parse --show-toplevel`
cd ${project_dir}/project-sonar

baseuri='https://opendata.rapid7.com'

schemas=(
    /sonar.rdns_v2/
)
#    /sonar.fdns_v2/

for schema in ${schemas[@]}
do
    schemafile=`curl -s ${baseuri}${schema} | grep "schema.json" | cut -d '"' -f2`
    echo "downloading shared schema from" $schemafile
    wget --no-verbose --show-progress --progress=dot:mega \
    ${baseuri}${schemafile} -O schemas/json_schema.json
    exit
    if [ $schema == "/sonar.rdns_v2/" ]; then
        echo "downloading new rdns schema from" $schemafile
        wget --no-verbose --show-progress --progress=dot:mega \
        ${baseuri}${schemafile} -O schemas/rdns_schema.json
    elif [ $schema == "/sonar.fdns_v2/" ]; then
        echo "downloading new fdns schema from" $schemafile
        wget --no-verbose --show-progress --progress=dot:mega \
        ${baseuri}${schemafile} -O schemas/fdns_schema.json
    else
        echo "unknown error"
        exit
    fi
done

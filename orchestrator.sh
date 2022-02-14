#!/bin/bash

set -e

# handle downloads of specific datasets if specified
# to allow for concurrent downloads across different containers
# ie MODE=LOAD ./orchestrator.sh rdns_v2:rdns.json.gz

if [ "${MODE}" != "PRINT" ] && [ "${MODE}" != "LOAD" ]; then
   echo "envionment variable MODE must be set to PRINT or LOAD"
   exit 1
fi

source datasets.sh

if [ -n "$1" ]
then
    sonardatasets=(
        $1
    )
fi

if [ "${MODE}" == "LOAD" ]; then
    gcloud auth activate-service-account --key-file=gcp-svc-sonar.json
    bq_ds_exists=`bq ls -d | { grep -w sonar || :; }`
    if [ -n "$bq_ds_exists" ]; then
        echo "not creating dataset sonar as already exists"
    else
        echo "creating new sonar dataset"
        bq --format pretty mk sonar
    fi
fi

for set in ${sonardatasets[@]}
do
    category=${set%%:*}
    dataset=${set##*:}
    base_sonar_url='https://opendata.rapid7.com/sonar.'${category}'/'
    sonarset_name=`echo ${dataset} | sed 's/'${category}'_//' | cut -d "." -f1`
    latest_tarball=`curl --silent ${base_sonar_url} \
    | grep '/sonar.'${category}'/' | grep ${dataset} \
    | awk -F '"' '{print $5}' | sed 's/>//' | sed 's/<\/a><\/td>//'`
    latest_tarball_download_uri=${base_sonar_url}${latest_tarball}
    #if MODE print then print the download uri
    if [ "${MODE}" == "PRINT" ]; then
        echo ${latest_tarball_download_uri}
    elif [ "${MODE}" == "LOAD" ]; then
        echo "starting download operation for" $latest_tarball "from" $latest_tarball_download_uri
        ./loader.sh ${latest_tarball_download_uri}
    fi
done

# if we are running in gcp after completing the job delete the associated compute instance

if [ `dig +short metadata.google.internal` ]; then
    echo 'we appear to be running in gcp, assusming batch load we will blast away the compute'
    NAME=$(curl -X GET http://metadata.google.internal/computeMetadata/v1/instance/name -H 'Metadata-Flavor: Google')
    ZONE=$(curl -X GET http://metadata.google.internal/computeMetadata/v1/instance/zone -H 'Metadata-Flavor: Google')
    gcloud --quiet compute instances delete $NAME --zone=$ZONE
fi

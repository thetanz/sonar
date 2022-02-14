#!/bin/bash

set -e

download_url=${1}

if [ -z "${download_url}" ]; then   
   echo "usage: ${0} https://rapid7-tarball-location"
   exit 1
fi

gcloud auth activate-service-account --key-file=gcp-svc-sonar.json

filename=`echo ${download_url} | cut -d - -f5`
file_no_extn=${filename%%.*}

echo "loader job recieved for dataset" "'"${file_no_extn}"'" "from" ${download_url}

bq_table_create() {
   exists=$(bq ls --max_results 1000 'sonar' | { grep -w $file_no_extn || :; })
   if [ -n "$exists" ]; then
      echo "table sonar.$file_no_extn already exists, removing"
      bq rm --force -t sonar.$file_no_extn
   fi
   echo "creating table sonar.$file_no_extn"
   bq --format pretty mk --table \
   --description "project sonar datasets for sauron" \
   sonar.$file_no_extn
}

file_bytecount() {
   ls -nR ${1} | grep -v '^d' | awk '{total += $5} END {print total}'
}

bq_table_create

echo "starting download of ${file_no_extn} from ${download_url}"

# https://stackoverflow.com/questions/66290522
wget --no-verbose --show-progress --progress=dot:mega \
-O ${file_no_extn}.json.gz ${download_url}

download_bytes=`file_bytecount ${file_no_extn}.json.gz`
echo "download complete (${download_bytes} bytes): ${file_no_extn}.json.gz"

#uploads to google cloud storage and loads data into big query
loader() {
   gsutil -o GSUtil:parallel_composite_upload_threshold=150M \
   -h 'Content-Type: application/json' -h 'Content-Encoding: gzip' \
   cp ${1}.json.gz gs://sonarbq/${1}.json
   echo "deleting local tarball: ${1}.json.gz"
   rm ${1}.json.gz
   echo "loading dataset into bigquery"
   bq load \
   --source_format=NEWLINE_DELIMITED_JSON \
   sonar.${1} \
   gs://sonarbq/${1}.json \
   ./bigquery.json
   echo "removing dataset from google cloud storage"
   gsutil rm gs://sonarbq/${1}.json
}

loader_chunks() {
   chunkname=`echo ${chunk} | cut -d - -f2`
   chunk_no_suffix=${chunk%%.*}
   chunk_id=`echo ${chunk} | cut -d - -f3`
   mv ${chunk} ${chunk_no_suffix}_${chunkname}.json
   echo "creating tarball from chunk"
   gzip ${chunk_no_suffix}_${chunkname}.json
   echo "starting upload ${chunk_count}/${total_chunks} to google cloud storage"
   gsutil -o GSUtil:parallel_composite_upload_threshold=150M \
   -h 'Content-Type: application/json' -h 'Content-Encoding: gzip' \
   cp ${chunk_no_suffix}_${chunkname}.json.gz gs://sonarbq/${chunk_no_suffix}_${chunkname}.json
   echo "loading chunk into bigquery"
   # https://cloud.google.com/bigquery/docs/schemas#specifying_a_schema_file_when_you_load_data 
   bq load \
   --source_format=NEWLINE_DELIMITED_JSON \
   sonar.${chunk_no_suffix} \
   gs://sonarbq/${chunk_no_suffix}_${chunkname}.json \
   ./bigquery.json
   echo "removing chunk from disk & google cloud storage"
   rm ${chunk_no_suffix}_${chunkname}.json.gz
   gsutil rm gs://sonarbq/${chunk_no_suffix}_${chunkname}.json
}

# 4294967296 == 4gb
if [ $download_bytes -gt 4294967296 ]
then
   echo "tarball greater than 4gb & too big for compressed bigquery load!"
   # https://cloud.google.com/bigquery/docs/loading-data-cloud-storage
   echo "extracting archive - this will take some time"
   gunzip ${file_no_extn}.json.gz
   echo "creating chunks of 3 million line-delimited json objects"
   split -l 3000000 -a 4 ${file_no_extn}.json ${file_no_extn}.json-
   rm ${file_no_extn}.json
   total_chunks=`ls ${file_no_extn}.json-* | wc -l | tr -d ' '`
   chunk_count=1
   for chunk in ${file_no_extn}.json-*
   do
      echo "processing chunk ${chunk_count}/${total_chunks}"
      loader_chunks
      ((++chunk_count))
   done
else
   echo "tarball is under 4gb - performing gzip upload to google cloud storage"
   loader ${file_no_extn}
fi

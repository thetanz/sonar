#!/bin/bash

# reads in from datasets.sh - for each, created a gcp compute task to run the container image to process the dataset

set -e

gcloud auth activate-service-account --key-file=gcp-svc-sonar.json

gcloud auth configure-docker gcr.io

docker build . -t gcr.io/YOUR_GCP_PROJECT/sonar

docker push gcr.io/YOUR_GCP_PROJECT/sonar

source datasets.sh

# we would ideally use --preemptible to use cheaper compute but a number of these operations run for too long thus get preempted before the task is complete

for set in ${sonardatasets[@]}
do
    dataset=${set##*:}
    dataset_no_extn=${dataset%%.*}
    dataset_hyphen=`echo $dataset | tr '.' '-' | tr '_' '-'`
    job_id=`echo ${RANDOM} | tr '[0-9]' '[a-z]'`
    echo "creating job runner for ${set} (sonarjob-${dataset_hyphen}) id:${job_id}"
    gcloud compute instances create-with-container \
    sonarjob-${dataset_hyphen} \
    --labels job=${job_id} \
    --container-arg "${set}" \
    --container-restart-policy never \
    --container-image gcr.io/YOUR_GCP_PROJECT/sonar \
    --boot-disk-auto-delete \
    --boot-disk-size 512GB \
    --boot-disk-type pd-ssd \
    --description 'https://github.com/thetanz/sonar' \
    --machine-type e2-medium \
    --no-restart-on-failure \
    --zone us-east1-b
done

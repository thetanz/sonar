FROM google/cloud-sdk:alpine

LABEL org.opencontainers.image.source https://github.com/thetanz/sonar

RUN apk --update add jq gzip curl ca-certificates bind-tools
# https://github.com/Yelp/dumb-init/issues/73 use GNU wget

RUN update-ca-certificates
RUN apk add wget

COPY *.sh .
COPY bigquery.json bigquery.json

ENTRYPOINT ["MODE=LOAD /orchestrator.sh"]
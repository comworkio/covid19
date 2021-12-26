#!/usr/bin/env bash

echo "ELASTIC_URL=${ELASTIC_URL}" > .env
echo "ELASTIC_USERNAME=${ELASTIC_USERNAME}" >> .env
echo "ELASTIC_PASSWORD=${ELASTIC_PASSWORD}" >> .env

docker rmi -f "comworkio/covid-stats:latest"
docker-compose -f docker-compose-x86-min.yml up -d --force-recreate

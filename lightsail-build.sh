#!/usr/bin/env bash

cp /home/runner/secret /home/runner/${SITE_NAME}/.env
set -e
DIR=$PWD
PHP_IMG="wesayhowhigh/php-app"
NODE_IMG="wesayhowhigh/node-build"
TAG="latest"
cd $DIR
docker run --rm -w /opt -v $DIR:/opt $PHP_IMG composer install --no-dev
docker run --rm -w /opt -v $DIR:/opt $NODE_IMG npm install --registry https://npm-proxy.fury.io/iQe2xgJjTKscoNsbBNit/jump/
docker run --rm -w /opt -v $DIR:/opt $NODE_IMG npm run build
IMAGE=683707242425.dkr.ecr.eu-west-1.amazonaws.com/site-${SITE_NAME}:${TAG}
docker build -t ${IMAGE} .
docker push ${IMAGE}

DOCKER_LOGIN_CMD=aws ecr-get login --no-include-email
ssh ubuntu@${ORIGIN_SERVER_IP} -c "${DOCKER_LOGIN_CMD}"
ssh ubuntu@${ORIGIN_SERVER_IP} -c "docker-compose up -d -e IMAGE=${IMAGE} -e TAG=${TAG}"

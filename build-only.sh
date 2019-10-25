#!/bin/bash

set -e

mkdir -p /home/runner/.composer

cp /home/runner/secrets/${SITE_NAME} /home/runner/${SEMAPHORE_PROJECT_NAME}/.env
cp /home/runner/composer-auth.json /home/runner/.composer/auth.json

DIR=$PWD
PHP_IMG="wesayhowhigh/php-app"
NODE_IMG="wesayhowhigh/node-build"
TAG=v-${SEMAPHORE_BUILD_NUMBER}

cd $DIR

# TEMPORARY COMPOSER FIX
docker run --rm -w /opt -v $DIR:/opt -v /home/runner/.composer:/root/.composer $PHP_IMG composer update mirrors

docker run --rm -w /opt -v $DIR:/opt -v /home/runner/.composer:/root/.composer $PHP_IMG composer install --no-dev
docker run --rm -w /opt -v $DIR:/opt $NODE_IMG npm install --registry https://npm-proxy.fury.io/iQe2xgJjTKscoNsbBNit/jump/
docker run --rm -w /opt -v $DIR:/opt $NODE_IMG npm run build

if [ -d "./vendor/wayfair/hypernova-php/src/plugins" ]; then
  # Fix hypernova plugins folder case
  docker run --rm -w /opt -v $DIR:/opt $PHP_IMG mv ./vendor/wayfair/hypernova-php/src/plugins ./vendor/wayfair/hypernova-php/src/Plugins
  # End: Hypernova hacks
fi

IMAGE=${REGISTRY_ID}.dkr.ecr.eu-west-1.amazonaws.com/${SITE_NAME}:${TAG}
docker build -t ${IMAGE} .
docker push ${IMAGE}

DOCKER_LOGIN_CMD=$(aws ecr get-login --no-include-email)
echo DOCKER_LOGIN_CMD


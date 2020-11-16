#!/bin/bash

set -e

[ -z "$REGISTRY_ID" ] && REGISTRY_ID=683707242425

mkdir -p /home/runner/.composer

cp /home/runner/secret /home/runner/${SEMAPHORE_PROJECT_NAME}/.env
cp /home/runner/composer-auth.json /home/runner/.composer/auth.json
cp /home/runner/nginx.conf /home/runner/${SEMAPHORE_PROJECT_NAME}/nginx.conf

DIR=$PWD
PHP_IMG="wesayhowhigh/php-app"
NODE_IMG="wesayhowhigh/node-build"
TAG=v-${SEMAPHORE_DEPLOY_NUMBER}-${SEMAPHORE_BUILD_NUMBER}

cd $DIR

# Authenticate with Docker Hub
echo $DOCKER_PASSWORD | docker login --username "$DOCKER_USERNAME" --password-stdin

docker run --rm -w /opt -v $DIR:/opt -v /home/runner/.composer:/root/.composer $PHP_IMG composer install --no-dev --ignore-platform-reqs
docker run --rm -w /opt -v $DIR:/opt $NODE_IMG npm install --registry https://npm-proxy.fury.io/iQe2xgJjTKscoNsbBNit/jump/
docker run --rm -w /opt -v $DIR:/opt $NODE_IMG npm run build

if [ -d "./vendor/wayfair/hypernova-php/src/plugins" ]; then
  # Fix hypernova plugins folder case
  docker run --rm -w /opt -v $DIR:/opt $PHP_IMG mv ./vendor/wayfair/hypernova-php/src/plugins ./vendor/wayfair/hypernova-php/src/Plugins
  # End: Hypernova hacks
fi

IMAGE=${REGISTRY_ID}.dkr.ecr.eu-west-1.amazonaws.com/site-${SITE_NAME}:${TAG}
docker build -t ${IMAGE} .
docker push ${IMAGE}

ssh-keyscan -t rsa ${ORIGIN_SERVER_IP} >> ~/.ssh/known_hosts

ssh ubuntu@${ORIGIN_SERVER_IP} cp docker-compose.prod.yml docker-compose.prod.backup.yml

DOCKER_LOGIN_CMD=$(aws ecr get-login --no-include-email)
ssh ubuntu@${ORIGIN_SERVER_IP} ${DOCKER_LOGIN_CMD}
ssh ubuntu@${ORIGIN_SERVER_IP} docker pull ${IMAGE}

curl -o ./docker-compose.prod.yml https://raw.githubusercontent.com/wesayhowhigh/lightsail-pipeline/master/docker-compose.prod.yml
sed -i "s|IMAGE_GOES_HERE|${IMAGE}|g" docker-compose.prod.yml

curl -o ./cron.sh https://raw.githubusercontent.com/wesayhowhigh/lightsail-pipeline/master/cron.sh

scp cron.sh ubuntu@${ORIGIN_SERVER_IP}:~/cron.sh
scp docker-compose.prod.yml ubuntu@${ORIGIN_SERVER_IP}:~/docker-compose.prod.yml
ssh ubuntu@${ORIGIN_SERVER_IP} docker-compose -f docker-compose.prod.yml up -d

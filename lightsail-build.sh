#!/bin/bash

set -e

mkdir -p /home/runner/.composer

cp /home/runner/secret /home/runner/${SEMAPHORE_PROJECT_NAME}/.env
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

IMAGE=683707242425.dkr.ecr.eu-west-1.amazonaws.com/site-${SITE_NAME}:${TAG}
docker build -t ${IMAGE} .
docker push ${IMAGE}

ssh-keyscan -t rsa ${ORIGIN_SERVER_IP} >> ~/.ssh/known_hosts

ssh ubuntu@${ORIGIN_SERVER_IP} cp docker-compose.prod.yml docker-compose.prod.backup.yml

DOCKER_LOGIN_CMD=$(aws ecr get-login --no-include-email)
ssh ubuntu@${ORIGIN_SERVER_IP} ${DOCKER_LOGIN_CMD}
ssh ubuntu@${ORIGIN_SERVER_IP} docker pull ${IMAGE}

curl -o ./docker-compose.prod.yml https://raw.githubusercontent.com/wesayhowhigh/lightsail-pipeline/master/docker-compose.prod.yml
sed -i "s|IMAGE_GOES_HERE|${IMAGE}|g" docker-compose.prod.yml

scp docker-compose.prod.yml ubuntu@${ORIGIN_SERVER_IP}:~/docker-compose.prod.yml
ssh ubuntu@${ORIGIN_SERVER_IP} docker-compose -f docker-compose.prod.yml up -d

ssh ubuntu@${ORIGIN_SERVER_IP} docker system prune --all

EMAIL_BODY="<html><body><a href=\"https://github.com/${SEMAPHORE_REPO_SLUG}/commit/${REVISION}\">View commit</a></body></html>"
curl "https://api.postmarkapp.com/email" -X POST -H "Accept: application/json" -H "Content-Type: application/json" -H "X-Postmark-Server-Token: ${POSTMARK_SERVER_TOKEN}" -d "{From: '\"Semaphore\" <build@jump-ops.com>', To: 'alerts@wesayhowhigh.com', Subject: '${SEMAPHORE_PROJECT_NAME} release', HtmlBody: '${EMAIL_BODY}'}"

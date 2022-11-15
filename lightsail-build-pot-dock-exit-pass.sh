#!/bin/bash

set -e


ssh-keyscan -t rsa ${ORIGIN_SERVER_IP} >> ~/.ssh/known_hosts

ssh ubuntu@${ORIGIN_SERVER_IP} sudo chown -R 1001:1001 ./ftp/autostore/upload
ssh ubuntu@${ORIGIN_SERVER_IP} sudo chown -R 1002:1002 ./ftp/mandata/upload

#!/bin/bash

set -e

ssh ubuntu@${ORIGIN_SERVER_IP} sudo chown -R 1001:1001 ./ftp/autostore/upload
ssh ubuntu@${ORIGIN_SERVER_IP} sudo chown -R 1002:1002 ./ftp/mandata/upload

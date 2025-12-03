#!/bin/bash

mongo --nodb init_mongo.js
echo -e "security:\n authorization: enabled" >> /etc/mongod.conf
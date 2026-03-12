#! /bin/bash

docker build  -t gsrd_image  --build-arg username=$(whoami)  .

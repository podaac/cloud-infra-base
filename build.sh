#!/bin/bash

mkdir "$(dirname $BASH_SOURCE)/build"
cd "$(dirname $BASH_SOURCE)/lambdas"
zip -r ../build/lambdas.zip .

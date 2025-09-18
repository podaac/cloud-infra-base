#!/bin/bash

VERSION=$(<"$(dirname $BASH_SOURCE)/VERSION")

mkdir -p "$(dirname $BASH_SOURCE)/build"
rm -f ../build/carpathia-lambdas-${VERSION}.zip
cd "$(dirname $BASH_SOURCE)/lambdas"
zip -r9 ../build/carpathia-lambdas-${VERSION}.zip .

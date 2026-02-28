#!/bin/bash
set -x

VERSION=$(tr -d '\n' < "$(dirname "$BASH_SOURCE")/VERSION")
echo "VERSION: '$VERSION'"

mkdir -p "$(dirname "$BASH_SOURCE")/build"
rm -f "$(dirname "$BASH_SOURCE")/build/carpathia-lambdas-${VERSION}.zip"
cd "$(dirname "$BASH_SOURCE")/lambdas"
zip -r9 "../build/carpathia-lambdas-${VERSION}.zip" .

ls -la "$(dirname "$BASH_SOURCE")/build"
echo "Created: $(dirname "$BASH_SOURCE")/build/carpathia-lambdas-${VERSION}.zip"

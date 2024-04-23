#!/bin/bash

current_dir=$(basename "$PWD")
if [ "$current_dir" != "contracts" ]; then
  echo "This script must be run from the /contracts directory. Aborting."
  exit 1
fi

. ../../.env

forge create src/SeismicNotifier.sol:SeismicNotifier \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY > deploy_out.txt
CONTRACT_ADDR=$(awk '/Deployed to:/ {print $3}' deploy_out.txt)

echo "{ 
    \"address\": \"$CONTRACT_ADDR\"
}" > out/SeismicNotifier.sol/deployment.json
rm deploy_out.txt
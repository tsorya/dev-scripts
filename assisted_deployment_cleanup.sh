#!/usr/bin/env bash

source logging.sh
source common.sh

TEST_INFRA_DIR=$WORKING_DIR/test-infra
if ! [ "$NODES_PLATFORM" = "assisted" ]; then
  exit 0
fi


function delete_all() {
    pushd $TEST_INFRA_DIR
    skipper make destroy
    popd
}

delete_all
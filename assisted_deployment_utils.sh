#!/usr/bin/env bash
set -o pipefail
source common.sh
source logging.sh

TEST_INFRA_DIR=$WORKING_DIR/test-infra

function destroy_assisted_nodes(){
  echo "Destroying assisted_deployment vms"
  run_assited_command "destroy_nodes"
}

function run_assited_command () {
  pushd $TEST_INFRA_DIR
  source scripts/assisted_deployment.sh
  run_skipper_make_command "$1"
  popd
}


function wait_for_assited_cluster() {
  pushd $TEST_INFRA_DIR
  source scripts/assisted_deployment.sh
  wait_for_cluster "$1"
  popd
}

"$@"

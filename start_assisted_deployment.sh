#!/usr/bin/env bash

TEST_INFRA_BRANCH=${TEST_INFRA_BRANCH:-"master"}
TEST_INFRA_DIR=$WORKING_DIR/test-infra


function install_env() {
  pushd $WORKING_DIR
  if cd $TEST_INFRA_DIR;then
    git fetch --all && git reset --hard origin/$TEST_INFRA_BRANCH;
  else
    git clone --branch $TEST_INFRA_BRANCH https://github.com/tsorya/test-infra.git;
  fi
  popd
  pushd $TEST_INFRA_DIR
  sudo KUBECONFIG=$KUBECONFIG ./create_full_environment.sh
  popd

}

# ADD ALL RELEVANT OS ENVS
function start_full_flow() {
    pushd $TEST_INFRA_DIR
    cp $KUBECONFIG kubeconfig
    sudo /usr/local/bin/skipper make run_full_flow NUM_MASTERS=$NUM_MASTERS NUM_WORKERS=$NUM_WORKERS KUBECONFIG=$PWD/kubeconfig BASE_DOMAIN=$BASE_DOMAIN CLUSTER_NAME=$CLUSTER_NAME
    popd
}

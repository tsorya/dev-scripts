#!/usr/bin/env bash
set -x
set -e

source logging.sh
source utils.sh
source common.sh

if ! [ "$NODES_PLATFORM" = "assisted" ]; then
  source ocp_install_env.sh
  source rhcos.sh
fi

# Do some PULL_SECRET sanity checking
if [[ "${OPENSHIFT_RELEASE_IMAGE}" == *"registry.svc.ci.openshift.org"* ]]; then
    if [[ "${PULL_SECRET}" != *"registry.svc.ci.openshift.org"* ]]; then
        echo "Please get a valid pull secret for registry.svc.ci.openshift.org."
        exit 1
    fi
fi

if [[ "${PULL_SECRET}" != *"cloud.openshift.com"* ]]; then
    echo "Please get a valid pull secret for cloud.openshift.com."
    exit 1
fi

if [ "$NODES_PLATFORM" = "assisted" ]; then
  source assisted_deployment.sh
  if [ "$INSTALL" == "y" ]; then
    run_assisted_flow_with_install
  else
    run_assisted_flow
  fi
  API_VIP=$(network_ip ${ASSISTED_NETWORK:-"test-infra-net"})
  echo "server=/api.${CLUSTER_DOMAIN}/${API_VIP}" | sudo tee -a /etc/NetworkManager/dnsmasq.d/openshift-${CLUSTER_NAME}.conf
  sudo systemctl reload NetworkManager
  exit 0
fi

# NOTE: This is equivalent to the external API DNS record pointing the API to the API VIP
if [ "$MANAGE_BR_BRIDGE" == "y" ] ; then
    if [[ -n "${EXTERNAL_SUBNET_V6}" ]]; then
        API_VIP=$(dig -t AAAA +noall +answer "api.${CLUSTER_DOMAIN}" @$(network_ip ${BAREMETAL_NETWORK_NAME}) | awk '{print $NF}')
        INGRESS_VIP=$(python -c "from ansible.plugins.filter import ipaddr; print(ipaddr.nthhost('"$EXTERNAL_SUBNET_V6"', 4))")
    else
        API_VIP=$(dig +noall +answer "api.${CLUSTER_DOMAIN}" @$(network_ip ${BAREMETAL_NETWORK_NAME}) | awk '{print $NF}')
        INGRESS_VIP=$(python -c "from ansible.plugins.filter import ipaddr; print(ipaddr.nthhost('"$EXTERNAL_SUBNET_V4"', 4))")
    fi
    echo "address=/api.${CLUSTER_DOMAIN}/${API_VIP}" | sudo tee -a /etc/NetworkManager/dnsmasq.d/openshift-${CLUSTER_NAME}.conf
    echo "address=/.apps.${CLUSTER_DOMAIN}/${INGRESS_VIP}" | sudo tee -a /etc/NetworkManager/dnsmasq.d/openshift-${CLUSTER_NAME}.conf
    echo "listen-address=::1" | sudo tee -a /etc/NetworkManager/dnsmasq.d/openshift-${CLUSTER_NAME}.conf
    sudo systemctl reload NetworkManager
else
    if [[ -n "${EXTERNAL_SUBNET_V6}" ]]; then
        API_VIP=$(dig -t AAAA +noall +answer "api.${CLUSTER_DOMAIN}"  | awk '{print $NF}')
    else
        API_VIP=$(dig +noall +answer "api.${CLUSTER_DOMAIN}"  | awk '{print $NF}')
    fi
    INGRESS_VIP=$(dig +noall +answer "test.apps.${CLUSTER_DOMAIN}" | awk '{print $NF}')
fi

if [ ! -f ${OCP_DIR}/install-config.yaml ]; then
    # Validate there are enough nodes to avoid confusing errors later..
    NODES_LEN=$(jq '.nodes | length' ${NODES_FILE})
    if (( $NODES_LEN < ( $NUM_MASTERS + $NUM_WORKERS ) )); then
        echo "ERROR: ${NODES_FILE} contains ${NODES_LEN} nodes, but ${NUM_MASTERS} masters and ${NUM_WORKERS} workers requested"
        exit 1
    fi

    # Create a nodes.json file
    mkdir -p ${OCP_DIR}
    jq '{nodes: .}' "${NODES_FILE}" | tee "${BAREMETALHOSTS_FILE}"

    # Create install config for openshift-installer
    generate_ocp_install_config ${OCP_DIR}
fi

# Call openshift-installer to deploy the bootstrap node and masters
create_cluster ${OCP_DIR}

# Kill the dnsmasq container on the host since it is performing DHCP and doesn't
# allow our pod in openshift to take over.  We don't want to take down all of ironic
# as it makes cleanup "make clean" not work properly.
for name in dnsmasq ironic-inspector ; do
    sudo podman ps | grep -w "$name$" && sudo podman stop $name
done

echo "Cluster up, you can interact with it via oc --config ${KUBECONFIG} <command>"

#!/usr/bin/env bash
set -xeEo pipefail
GIT_ROOT=$(git rev-parse --show-toplevel)
for f in $GIT_ROOT/test/e2e/util/*.sh; do source $f; done

trap error ERR
trap "finish backpack resources/backpack_role.yaml" EXIT

function functional_test_backpack {
  backpack_requirements
  test_init $BENCHMARK_DIR/backpack_$1.yaml


  if [[ $1 == "daemonset" ]]
  then
    wait_for_backpack $uuid
  else
    byowl_pod=$(get_pod "app=byowl-$uuid" 300)
    wait_for "kubectl -n my-ripsaw wait --for=condition=Initialized pods/$byowl_pod --timeout=500s" "500s" $byowl_pod
    wait_for "kubectl -n my-ripsaw  wait --for=condition=complete -l app=byowl-$uuid jobs --timeout=500s" "500s" $byowl_pod
  fi
  
  indexes="cpu_vulnerabilities-metadata cpuinfo-metadata dmidecode-metadata k8s_configmaps-metadata k8s_namespaces-metadata k8s_nodes-metadata k8s_pods-metadata lspci-metadata meminfo-metadata sysctl-metadata"
  if check_es "${long_uuid}" "${indexes}"
  then
    echo "Backpack test: Success"
  else
    echo "Failed to find data in ES"
    exit 1
  fi
}

figlet $(basename $0)
functional_test_backpack daemonset
functional_test_backpack init

#!/usr/bin/env bash
set -xeEo pipefail
GIT_ROOT=$(git rev-parse --show-toplevel)
for f in $GIT_ROOT/test/e2e/util/*.sh; do source $f; done

trap error ERR
trap "finish backpack resources/backpack_role.yaml" EXIT

function functional_test_backpack {
  backpack_requirements
  test_init backpack $2


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

function wait_for_backpack() {
  echo "Waiting for backpack to complete before starting benchmark test"

  uuid=$1
  count=0
  max_count=60
  while [[ $count -lt $max_count ]]
  do
    if [[ `kubectl -n my-ripsaw get daemonsets backpack-$uuid` ]]
    then
      desired=`kubectl -n my-ripsaw get daemonsets backpack-$uuid | grep -v NAME | awk '{print $2}'`
      ready=`kubectl -n my-ripsaw get daemonsets backpack-$uuid | grep -v NAME | awk '{print $4}'`
      if [[ $desired -eq $ready ]]
      then
        echo "Backpack complete. Starting benchmark"
        break
      fi
    fi
    count=$((count + 1))
    if [[ $count -ne $max_count ]]
    then
      sleep 6
    else
      echo "Backpack failed to complete. Exiting"
      exit 1
    fi
  done
}

figlet $(basename $0)
functional_test_backpack daemonset
functional_test_backpack init

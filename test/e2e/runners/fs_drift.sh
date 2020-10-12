#!/usr/bin/env bash
set -xeEo pipefail
GIT_ROOT=$(git rev-parse --show-toplevel)
for f in $GIT_ROOT/test/e2e/util/*.sh; do source $f; done
trap error ERR
trap "finish fs_drift" EXIT

function functional_test_fs_drift {
  test_name=$1
  cr=$2
  echo "Performing: ${test_name}"
  test_init ${cr}

  count=0
  while [[ $count -lt 24 ]]; do
    if [[ `kubectl get pods -l app=fs-drift-benchmark-$uuid --namespace my-ripsaw -o name | cut -d/ -f2 | grep client` ]]; then
      fsdrift_pod=$(kubectl get pods -l app=fs-drift-benchmark-$uuid --namespace my-ripsaw -o name | cut -d/ -f2 | grep client)
      count=30
    fi
    if [[ $count -ne 30 ]]; then
      sleep 5
      count=$((count + 1))
    fi
  done
  echo fsdrift_pod $fs_drift_pod
  wait_for "kubectl wait --for=condition=Initialized pods/$fsdrift_pod -n my-ripsaw --timeout=500s" "500s" $fsdrift_pod
  wait_for "kubectl wait --for=condition=complete -l app=fs-drift-benchmark-$uuid jobs -n my-ripsaw --timeout=100s" "200s" $fsdrift_pod

  indexes="ripsaw-fs-drift-results ripsaw-fs-drift-rsptimes ripsaw-fs-drift-rates-over-time"
  if check_es "${long_uuid}" "${indexes}"
  then
    echo "${test_name} test: Success"
  else
    echo "Failed to find data for ${test_name} in ES"
    kubectl logs "$fsdrift_pod" -n my-ripsaw
    exit 1
  fi
}

figlet $(basename $0)
functional_test_fs_drift "fs-drift" $BENCHMARK_DIR/fs_drift.yaml
functional_test_fs_drift "fs-drift hostpath" $BENCHMARK_DIR/fs_drift_hostpath.yaml

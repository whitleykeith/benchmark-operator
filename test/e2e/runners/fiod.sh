#!/usr/bin/env bash
set -xeEo pipefail
GIT_ROOT=$(git rev-parse --show-toplevel)
for f in $GIT_ROOT/test/e2e/util/*.sh; do source $f; done

trap error ERR
trap "finish fiod $GIT_ROOT/resources/kernel-cache-drop-clusterrole.yaml" EXIT


function functional_test_fio {
  kubectl apply -f $GIT_ROOT/resources/kernel-cache-drop-clusterrole.yaml
  test_name=$1
  cr=$2
  echo "Performing: ${test_name}"
  test_init $cr


  pod_count "app=fio-benchmark-$uuid" 2 300  
  wait_for "kubectl -n my-ripsaw wait --for=condition=Initialized -l app=fio-benchmark-$uuid pods --timeout=300s" "300s"
  fio_pod=$(get_pod "app=fiod-client-$uuid" 300)
  wait_for "kubectl wait --for=condition=Initialized pods/$fio_pod -n my-ripsaw --timeout=500s" "500s" $fio_pod
  wait_for "kubectl wait --for=condition=complete -l app=fiod-client-$uuid jobs -n my-ripsaw --timeout=700s" "700s" $fio_pod

  indexes="ripsaw-fio-results ripsaw-fio-log ripsaw-fio-analyzed-result"
  if check_es "${long_uuid}" "${indexes}"
  then
    echo "${test_name} test: Success"
  else
    echo "Failed to find data for ${test_name} in ES"
    kubectl logs "$fio_pod" -n my-ripsaw
    exit 1
  fi
}

figlet $(basename $0)
kubectl label nodes -l node-role.kubernetes.io/worker=kernel-cache-dropper=yes --overwrite || true
functional_test_fio "Fio distributed" $BENCHMARK_DIR/fiod.yaml
functional_test_fio "Fio distributed - bsrange" $BENCHMARK_DIR/fiod_bsrange.yaml
functional_test_fio "Fio hostpath distributed" $BENCHMARK_DIR/fiod_hostpath.yaml

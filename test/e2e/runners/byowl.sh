#!/usr/bin/env bash
set -xeEo pipefail
GIT_ROOT=$(git rev-parse --show-toplevel)
for f in $GIT_ROOT/test/e2e/util/*.sh; do source $f; done

trap error ERR
trap "finish byowl" EXIT

function functional_test_byowl {
  test_init $BENCHMARK_DIR/byowl.yaml
  byowl_pod=$(get_pod "app=byowl-$uuid" 300)
  wait_for "kubectl -n my-ripsaw wait --for=condition=Initialized pods/$byowl_pod --timeout=500s" "500s" $byowl_pod
  wait_for "kubectl -n my-ripsaw  wait --for=condition=complete -l app=byowl-$uuid jobs --timeout=300s" "300s" $byowl_pod
  kubectl -n my-ripsaw logs "$byowl_pod" | grep "Test"
  echo "BYOWL test: Success"
}

figlet $(basename $0)
functional_test_byowl

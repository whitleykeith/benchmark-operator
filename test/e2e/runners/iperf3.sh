#!/usr/bin/env bash
set -xeEo pipefail
GIT_ROOT=$(git rev-parse --show-toplevel)
for f in $GIT_ROOT/test/e2e/util/*.sh; do source $f; done
trap error ERR
trap "finish iperf3" EXIT

function functional_test_iperf {
  test_init iperf3 $1

  iperf_server_pod=$(get_pod "app=iperf3-bench-server-$uuid" 300)
  wait_for "kubectl -n my-ripsaw wait --for=condition=Initialized -l app=iperf3-bench-server-$uuid pods --timeout=300s" "300s" $iperf_server_pod
  iperf_client_pod=$(get_pod "app=iperf3-bench-client-$uuid" 300)
  wait_for "kubectl -n my-ripsaw wait --for=condition=Initialized pods/$iperf_client_pod --timeout=500s" "500s" $iperf_client_pod
  wait_for "kubectl -n my-ripsaw wait --for=condition=complete -l app=iperf3-bench-client-$uuid jobs --timeout=100s" "100s" $iperf_client_pod
  sleep 5
  # ensuring that iperf actually ran and we can access metrics
  kubectl logs "$iperf_client_pod" --namespace my-ripsaw | grep "iperf Done."
  echo "iperf ${1}: Success"
}

figlet $(basename $0)
functional_test_iperf "hostnetwork"
functional_test_iperf "nohost"

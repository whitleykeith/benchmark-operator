#!/usr/bin/env bash
set -xeEo pipefail
GIT_ROOT=$(git rev-parse --show-toplevel)
for f in $GIT_ROOT/test/e2e/util/*.sh; do source $f; done
trap error ERR


# Custom kubeburner finish since it's more complicated than normal teardowns
function finish_kubeburner {
  # [[ $check_logs == 1 ]] && kubectl logs -l app=kube-burner-benchmark-$uuid -n my-ripsaw
  kubectl delete ns -l kube-burner-uuid=${long_uuid}
  finish kubeburner $GIT_ROOT/resources/kube-burner-role.yml
  
}

trap "finish_kubeburner" EXIT
# trap finish EXIT

function functional_test_kubeburner {
  PROMETHEUS_TOKEN=$(oc -n openshift-monitoring sa get-token prometheus-k8s)
  check_logs=0
  workload_name=$1
  kubectl apply -f $GIT_ROOT/resources/kube-burner-role.yml
  test_init "kube-burner" $workload_name

  pod_count "app=kube-burner-benchmark-$uuid" 1 900
  wait_for "kubectl wait -n my-ripsaw --for=condition=complete -l app=kube-burner-benchmark-$uuid jobs --timeout=500s" "500s"

  index="ripsaw-kube-burner"
  if check_es "${long_uuid}" "${index}"
  then
    echo "kube-burner ${workload_name}: Success"
  else
    echo "Failed to find data for kube-burner ${workload_name} in ES"
    check_logs=1
    exit 1
  fi
  kubectl delete ns -l kube-burner-uuid=${long_uuid}
}

figlet $(basename $0)
functional_test_kubeburner cluster-density-metrics-aggregated
functional_test_kubeburner kubelet-density-metrics
functional_test_kubeburner kubelet-density-heavy-metrics

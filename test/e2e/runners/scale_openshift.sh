#!/usr/bin/env bash
set -xeEo pipefail
GIT_ROOT=$(git rev-parse --show-toplevel)
for f in $GIT_ROOT/test/e2e/util/*.sh; do source $f; done
trap error ERR
trap "finish scale_oc $GIT_ROOT/resources/scale_role.yaml" EXIT


function functional_test_scale_openshift {
  # Apply scale role and service account
  kubectl apply -f $GIT_ROOT/resources/scale_role.yaml.yaml

  test_init scale $1
  

  scale_pod=$(get_pod "app=scale-$uuid" 300)
  wait_for "kubectl -n my-ripsaw wait --for=condition=Initialized -l app=scale-$uuid pods --timeout=300s" "300s" $scale_pod
  wait_for "kubectl wait -n my-ripsaw --for=condition=complete -l app=scale-$uuid jobs --timeout=500s" "500s" $scale_pod

  index="openshift-cluster-timings"
  if check_es "${long_uuid}" "${index}"
  then
    echo "${test_name} test: Success"
  else
    echo "Failed to find data for ${test_name} in ES"
    kubectl logs "$scale_pod" -n my-ripsaw
    exit 1
  fi
  kubectl delete -f ${cr}
}

figlet $(basename $0)
functional_test_scale_openshift "up"
functional_test_scale_openshift "down"

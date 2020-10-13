#!/usr/bin/env bash
set -xeEo pipefail
GIT_ROOT=$(git rev-parse --show-toplevel)
for f in $GIT_ROOT/test/e2e/util/*.sh; do source $f; done
trap error ERR
trap "finish pgbench $RESOURCES_DIR/postgres.yaml" EXIT


function inject_postgres_ip {
  
}


# Note we don't test persistent storage here
function functional_test_pgbench {
  kubectl apply -f $RESOURCES_DIR/postgres.yaml
  test_init pgbench $1

  # get the postgres pod IP
  postgres_pod=$(get_pod 'app=postgres' 300)
  postgres_ip=0
  counter=0
  until [[ $postgres_ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ||  $counter -eq 10 ]]; do
    let counter+=1
    postgres_ip=$(kubectl get pod -n my-ripsaw $postgres_pod --template={{.status.podIP}})
    sleep 2
  done
  # deploy the test CR with the postgres pod IP
  sed s/host:/host:\ ${postgres_ip}/ tests/test_crs/valid_pgbench.yaml | kubectl apply -f -
  long_uuid=$(get_uuid 20)
  uuid=${long_uuid:0:8}

  pgbench_pod=$(get_pod "app=pgbench-client-$uuid" 300)
  wait_for "kubectl wait --for=condition=Initialized pods/$pgbench_pod -n my-ripsaw --timeout=360s" "360s" $pgbench_pod
  wait_for "kubectl wait --for=condition=Ready pods/$pgbench_pod -n my-ripsaw --timeout=60s" "60s" $pgbench_pod
  wait_for "kubectl wait --for=condition=Complete jobs -l app=pgbench-client-$uuid -n my-ripsaw --timeout=300s" "300s" $pgbench_pod

  index="ripsaw-pgbench-summary ripsaw-pgbench-raw"
  if check_es "${long_uuid}" "${index}"
  then
    echo "pgbench test: Success"
  else
    echo "Failed to find data for PGBench in ES"
    kubectl logs -n my-ripsaw $pgbench_pod
    exit 1
  fi
}

figlet $(basename $0)
functional_test_pgbench base

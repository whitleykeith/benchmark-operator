#!/usr/bin/env bash
set -xeEo pipefail
GIT_ROOT=$(git rev-parse --show-toplevel)
for f in $GIT_ROOT/test/e2e/util/*.sh; do source $f; done
trap error ERR
trap "finish hammerdb $RESOURCE_DIR/mssql.yaml" EXIT

function initdb_pod {
  echo "Setting up a MS-SQL DB Pod"
  kubectl apply -f $RESOURCE_DIR/mssql.yaml
  mssql_pod=$(get_pod "app=mssql" 300 "sql-server")
  kubectl wait --for=condition=Ready "pods/$mssql_pod" --namespace sql-server --timeout=300s
}

function functional_test_hammerdb {
  initdb_pod
  test_init $BENCHMARK_DIR/hammerdb.yaml

  # Wait for the workload pod to run the actual workload
  hammerdb_workload_pod=$(get_pod "app=hammerdb_workload-$uuid" 300)
  kubectl wait --for=condition=Initialized "pods/$hammerdb_workload_pod" --namespace my-ripsaw --timeout=400s
  kubectl wait --for=condition=complete -l app=hammerdb_workload-$uuid --namespace my-ripsaw jobs --timeout=500s

  index="ripsaw-hammerdb-results"
  if check_es "${long_uuid}" "${index}"
  then
    echo "Hammerdb test: Success"
  else
    echo "Failed to find data for HammerDB test in ES"
    kubectl logs "$hammerdb_workload_pod" --namespace my-ripsaw
    exit 1
  fi
}

figlet $(basename $0)
functional_test_hammerdb

#!/usr/bin/env bash

GIT_ROOT=$(git rev-parse --show-toplevel)

source $GIT_ROOT/test/e2e/util/common.sh
source $GIT_ROOT/test/e2e/util/benchmark_injections.sh


function test_init {
  benchmark_name=$1
  benchmark_profile=$2
  custom_func=$3

  test_name="$1 - $2"
  cr=$BENCHMARK_DIR/$1/$2.yaml
  echo "Performing: ${test_name}"
  cat $cr | enable_metadata | inject_prometheus_token | inject_postgres_ip | kubectl apply -f -
  long_uuid=$(get_uuid 20)
  uuid=${long_uuid:0:8}
}


function apply_operator {
  operator_requirements
  BENCHMARK_OPERATOR_IMAGE=${BENCHMARK_OPERATOR_IMAGE:-"quay.io/benchmark-operator/benchmark-operator:master"}
  cat resources/operator.yaml | yq w - 'spec.template.spec.containers.(name==benchmark-operator).image' $BENCHMARK_OPERATOR_IMAGE | kubectl apply -f -
  kubectl wait --for=condition=available "deployment/benchmark-operator" -n my-ripsaw --timeout=300s
}



function marketplace_setup {
  kubectl apply -f https://raw.githubusercontent.com/operator-framework/operator-marketplace/master/deploy/upstream/01_namespace.yaml
  kubectl apply -f https://raw.githubusercontent.com/operator-framework/operator-marketplace/master/deploy/upstream/02_catalogsourceconfig.crd.yaml
  kubectl apply -f https://raw.githubusercontent.com/operator-framework/operator-marketplace/master/deploy/upstream/03_operatorsource.crd.yaml
  kubectl apply -f https://raw.githubusercontent.com/operator-framework/operator-marketplace/master/deploy/upstream/04_service_account.yaml
  kubectl apply -f https://raw.githubusercontent.com/operator-framework/operator-marketplace/master/deploy/upstream/05_role.yaml
  kubectl apply -f https://raw.githubusercontent.com/operator-framework/operator-marketplace/master/deploy/upstream/06_role_binding.yaml
  kubectl apply -f https://raw.githubusercontent.com/operator-framework/operator-marketplace/master/deploy/upstream/07_upstream_operatorsource.cr.yaml
  kubectl apply -f https://raw.githubusercontent.com/operator-framework/operator-marketplace/master/deploy/upstream/08_operator.yaml
}



function operator_requirements {
  kubectl apply -f resources/namespace.yaml
  kubectl apply -f deploy
  kubectl apply -f resources/crds/ripsaw_v1alpha1_ripsaw_crd.yaml
  kubectl -n my-ripsaw get roles
  kubectl -n my-ripsaw get rolebindings
  kubectl -n my-ripsaw get podsecuritypolicies
  kubectl -n my-ripsaw get serviceaccounts
  kubectl -n my-ripsaw get serviceaccount benchmark-operator -o yaml
  kubectl -n my-ripsaw get role benchmark-operator -o yaml
  kubectl -n my-ripsaw get rolebinding benchmark-operator -o yaml
  kubectl -n my-ripsaw get podsecuritypolicy privileged -o yaml
}

function backpack_requirements {
  kubectl apply -f resources/backpack_role.yaml
  if [[ `command -v oc` ]]
  then
    if [[ `oc get securitycontextconstraints.security.openshift.io` ]]
    then
      oc adm policy -n my-ripsaw add-scc-to-user privileged -z benchmark-operator
      oc adm policy -n my-ripsaw add-scc-to-user privileged -z backpack-view
    fi
  fi
}

function create_operator {
  operator_requirements
  apply_operator
}

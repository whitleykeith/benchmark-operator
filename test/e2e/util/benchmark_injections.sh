#!/bin/bash

# Defines global behavior for injecting environment specifc variables into benchmark templates.

# enable metadata collection for specific test
function enable_metadata(){
  if [[ ! -z "$ES_SERVER" ]]; then 
      yq w - 'spec.elasticsearch.server' $ES_SERVER | yq w - 'spec.elasticsearch.port' ${ES_PORT:-80}
  else 
      yq w - 'spec.metadata.collection' 'false'
  fi 
}

# inject prometheus token for specific test
function inject_prometheus_token(){
  if [[ ! -z $PROMETHEUS_TOKEN ]]; then
    yq w - 'spec.prometheus.prom_token' $PROMETHEUS_TOKEN
  else
    tee
  fi
      
}

# inject postgres ip for pgbench tests 
function inject_postgres_ip(){
if [[ ! -z $POSTGRES_IP ]]; then
    yq w - 'spec.workload.args.databases[0].host' $POSTGRES_IP
  else
    tee
  fi
      
}
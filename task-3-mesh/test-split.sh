#!/bin/bash
for i in $(seq 1 40); do
  kubectl exec reporting-7b55d78b8d-vbgnn -n payments -c client -- curl -s http://ledger-api.payments.svc.cluster.local:8080/health
  echo ""
done

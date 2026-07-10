#!/bin/bash
for i in $(seq 1 40); do
  kubectl exec reporting-7b55d78b8d-vbgnn -n payments -c client -- curl -s http://ledger-api.payments.svc.cluster.local:8080/health
  echo ""
done | tee /tmp/canary-test-output.txt

echo "v1 count:"
grep -c '"version":"v1"' /tmp/canary-test-output.txt
echo "v2 count:"
grep -c '"version":"v2"' /tmp/canary-test-output.txt
echo "total lines:"
wc -l /tmp/canary-test-output.txt

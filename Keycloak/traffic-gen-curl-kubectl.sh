#!/bin/sh
kubectl exec -it -n sample deploy/curl -- /bin/sh -c '
URL1="http://flask-hello.sample.svc.cluster.local:80/hello";
URL2="http://httpbin.sample.svc.cluster.local:80/get";
trap "exit 0" INT TERM;
while true; do
  now=$(date --rfc-3339=seconds 2>/dev/null || date);
  (res1=$(curl -s -o /dev/null -w "%{http_code} %{time_total}" "$URL1"); echo "$now [flask-hello] $res1") &
  (res2=$(curl -s -o /dev/null -w "%{http_code} %{time_total}" "$URL2"); echo "$now [httpbin]     $res2") &
  wait; sleep 1;
done'

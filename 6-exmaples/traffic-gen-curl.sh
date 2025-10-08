#!/bin/sh
URL1="http://flask-hello.sample.svc.cluster.local:80/hello"
URL2="http://httpbin.sample.svc.cluster.local:80/get"

trap 'echo "Interrupted"; exit 0' INT TERM

while true; do
  now=$(date --rfc-3339=seconds 2>/dev/null || date)

  # flask-hello 요청
  (
    result1=$(curl -s -o /dev/null -w "%{http_code} %{time_total}" "$URL1" 2>&1)
    echo "$now [flask-hello] $result1"
  ) &

  # httpbin 요청
  (
    result2=$(curl -s -o /dev/null -w "%{http_code} %{time_total}" "$URL2" 2>&1)
    echo "$now [httpbin]     $result2"
  ) &

  # 백그라운드 프로세스 두 개가 모두 끝나길 잠깐 대기
  wait
  sleep 1
done


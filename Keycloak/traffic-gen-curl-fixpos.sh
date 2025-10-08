#!/bin/sh
URL1="http://flask-hello.sample.svc.cluster.local:80/hello"
URL2="http://httpbin.sample.svc.cluster.local:80/get"

count=0
# Ctrl+C 처리
trap 'printf "\033[?25h\nStopped\n"; exit 0' INT TERM
# 커서 숨김
printf "\033[?25l"

while true; do
  count=$((count+1))

  # flask-hello 요청 (응답코드/시간 + 바디)
  res1=$(curl -s -w " %{http_code} %{time_total}" "$URL1" 2>/dev/null)
  body1=$(echo "$res1" | awk '{print $1}')   # body만 따로 뽑기 힘들어서 전체를 두 단계로 분리할 수도 있음

  # httpbin 요청 (응답코드/시간 + 바디)
  res2=$(curl -s -w " %{http_code} %{time_total}" "$URL2" 2>/dev/null)

  # 화면 지우고 커서를 위로 올림 (2줄 고정 영역)
  printf "\033[2J\033[H"  # 화면 clear 후 커서를 홈(0,0)으로 이동
  printf "#%05d | flask-hello: %s\n" "$count" "$res1"
  printf "       | httpbin:     %s\n" "$res2"

  # 응답 내용(hello world / RBAC: access denied) 2줄 아래 고정 출력
  echo
  printf "flask-hello body: "
  curl -s "$URL1"
  echo
  printf "httpbin body:     "
  curl -s "$URL2"
  echo

  sleep 1
done


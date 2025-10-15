#!/bin/sh
URL1="http://flask-hello.sample.svc.cluster.local:80/hello"
URL2="http://httpbin.sample.svc.cluster.local:80/get"

count=0
# Ctrl+C process
trap 'printf "\033[?25h\nStopped\n"; exit 0' INT TERM
# hide cursor
printf "\033[?25l"

while true; do
  count=$((count+1))

  # flask-hello request (http response code/ total time  + body)
  res1=$(curl -s -w " %{http_code} %{time_total}" "$URL1" 2>/dev/null)
  body1=$(echo "$res1" | awk '{print $1}')   

  # httpbin request (http response code/ total time  + body)
  res2=$(curl -s -w " %{http_code} %{time_total}" "$URL2" 2>/dev/null)

  # clear the screen and move cursor up (2 lines fixed)
  printf "\033[2J\033[H"  # after screen clear, cursor move to home (0,0)
  printf "#%05d | flask-hello: %s\n" "$count" "$res1"
  printf "       | httpbin:     %s\n" "$res2"

  # response (hello world / RBAC: access denied) fixed print out 2 lines below
  echo
  printf "flask-hello body: "
  curl -s "$URL1"
  echo
  printf "httpbin body:     "
  curl -s "$URL2"
  echo

  sleep 1
done


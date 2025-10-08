#!/bin/sh
### ====== [CONFIG] Keycloak & Targets ======
# Keycloak token endpoint (예: https://<host>/realms/<realm>/protocol/openid-connect/token)
KC_TOKEN_URL="http://keycloak.192.168.10.151.nip.io/realms/myrealm/protocol/openid-connect/token"
CLIENT_ID="myclient"
USERNAME=myuser
PASSWORD=myuser

# 호출 대상
URL1="http://flask-hello.sample.svc.cluster.local:80/hello"
URL2="http://httpbin.sample.svc.cluster.local:80/get"

# 토큰 갱신 간격(초)
REFRESH_SEC=300

### ====== [FUNC] 토큰 발급(client_credentials) ======
get_token() {
  resp="$(curl -s -X POST "$KC_TOKEN_URL" \
    -H 'Content-Type: application/x-www-form-urlencoded' \
	-d "client_id=$CLIENT_ID" \
    -d "grant_type=password" \
   	-d "username=$USERNAME" \
	-d "password=$PASSWORD")"

  # jq 없이 access_token만 추출
  ACCESS_TOKEN="$(printf '%s' "$resp" | sed -n 's/.*"access_token":"\([^"]*\)".*/\1/p')"

  if [ -z "$ACCESS_TOKEN" ]; then
    # 에러 메시지 힌트 출력
    err="$(printf '%s' "$resp" | tr '\n' ' ' | cut -c1-200)"
    printf "\n[TokenError] Failed to get token. resp(head): %s\n" "$err" 1>&2
  else
    TOKEN_TS="$(date +%s)"
  fi
}

### ====== [INIT] ======
count=0
ACCESS_TOKEN=""
TOKEN_TS=0

# Ctrl+C 시 커서 복원
trap 'printf "\033[?25h\nStopped\n"; exit 0' INT TERM
# 커서 숨김
printf "\033[?25l"

### ====== [LOOP] ======
while true; do
  now_ts="$(date +%s)"
  # 토큰이 없거나 5분 지났으면 갱신
  if [ -z "$ACCESS_TOKEN" ] || [ $((now_ts - TOKEN_TS)) -ge $REFRESH_SEC ]; then
    get_token
  fi

  count=$((count+1))
  age=$((now_ts - TOKEN_TS))

  # 동시 호출(상태라인용)
  (
    res1="$(curl -s -o /dev/null -w "%{http_code} %{time_total}" \
      -H "Authorization: Bearer $ACCESS_TOKEN" "$URL1" 2>/dev/null)"
    printf "%s" "$res1" > /tmp/res1.$$ 
  ) &
  (
    res2="$(curl -s -o /dev/null -w "%{http_code} %{time_total}" \
      -H "Authorization: Bearer $ACCESS_TOKEN" "$URL2" 2>/dev/null)"
    printf "%s" "$res2" > /tmp/res2.$$
  ) &
  wait

  # 바디(짧은 응답 가정)도 각각 한 번씩
  body1="$(curl -s -H "Authorization: Bearer $ACCESS_TOKEN" "$URL1" 2>/dev/null)"
  body2="$(curl -s -H "Authorization: Bearer $ACCESS_TOKEN" "$URL2" 2>/dev/null)"

  # 결과 로드
  r1="$(cat /tmp/res1.$$ 2>/dev/null)"; rm -f /tmp/res1.$$
  r2="$(cat /tmp/res2.$$ 2>/dev/null)"; rm -f /tmp/res2.$$

  # 화면 고정 갱신
  printf "\033[2J\033[H"  # clear + 홈
  printf "#%05d | token_age=%3ds (refresh=%ds)\n" "$count" "$age" "$REFRESH_SEC"
  printf "       | flask-hello: %-15s\n" "$r1"
  printf "       | httpbin:     %-15s\n" "$r2"
  echo
  printf "flask-hello body: %s\n" "$body1"
  printf "httpbin body:     %s\n" "$body2"

  sleep 1
done


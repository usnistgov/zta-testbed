#!/bin/sh
#KC=http://keycloak.192.168.10.151.nip.io
KC=http://10.5.0.2:8080
REALM=myrealm
CLIENT_ID=myclient
USERNAME=myuser
PASSWORD=myuser

ACCESS_TOKEN=$(curl -s \
  -d "client_id=$CLIENT_ID" \
  -d "grant_type=password" \
  -d "username=$USERNAME" \
  -d "password=$PASSWORD" \
  "$KC/realms/$REALM/protocol/openid-connect/token" \
  | sed -E 's/.*"access_token":"([^"]+)".*/\1/')
#  | jq -r .access_token)


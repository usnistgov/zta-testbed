#!/bin/sh
KC=http://keycloak.192.168.10.151.nip.io
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
  | jq -r .access_token)

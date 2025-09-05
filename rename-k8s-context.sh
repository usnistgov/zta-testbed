#!/bin/sh
#set -x

# 첫 번째 인자를 변수에 담음 (예: ./rename-k8s-context.sh cluster1)
NEWNAME="$1"

# 인자가 비어있으면 에러 처리
if [ -z "$NEWNAME" ]; then
  echo "Usage: $0 <new-context-name>"
  exit 1
fi

kubectl config rename-context kubernetes-admin@kubernetes "$NEWNAME"

# show current context
kubectl config get-contexts

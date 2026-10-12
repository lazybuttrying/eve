#!/usr/bin/env bash
# geth 와 lighthouse 가 함께 읽는 32바이트 JWT 비밀키를 만듭니다. 이미 있으면 덮어쓰지 않습니다.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p jwt
if [ -s jwt/jwt.hex ]; then
  echo "jwt/jwt.hex 가 이미 있습니다. 그대로 씁니다."
else
  openssl rand -hex 32 | tr -d '\n' > jwt/jwt.hex
  chmod 644 jwt/jwt.hex
  echo "jwt/jwt.hex 생성 완료"
fi

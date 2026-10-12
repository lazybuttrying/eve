#!/usr/bin/env bash
# devnet 을 처음 상태로 되돌립니다: 컨테이너를 내리고 체인 데이터, genesis, 키를 모두 지웁니다.
# 다음 `docker compose up -d` 때 새 genesis(현재 시각 기준)로 새 체인이 시작됩니다.
# PC를 며칠 꺼 두었다가 다시 켰을 때도 이걸 쓰세요. 그대로 켜면 그동안의 빈 슬롯을 따라잡느라 오래 걸립니다.
set -euo pipefail
cd "$(dirname "$0")/.."
docker compose down --remove-orphans
# 컨테이너가 root 로 만든 파일이 있어서, 지우는 것도 컨테이너 안에서 합니다 (sudo 불필요).
docker run --rm -v "$PWD/data:/data" alpine:3.20 sh -c 'rm -rf /data/* /data/.[!.]* 2>/dev/null || true'
echo "초기화 완료. docker compose up -d 로 새 체인을 시작하세요."

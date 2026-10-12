#!/usr/bin/env bash
# 노드 상태를 한 번에 확인합니다. 사용: ./scripts/check.sh   (반복: watch -n 30 ./scripts/check.sh)
set -uo pipefail
RPC=${RPC:-http://127.0.0.1:8545}
BEACON=${BEACON:-http://127.0.0.1:5052}

rpc() {
  curl -s -m 5 -H 'Content-Type: application/json' \
    -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"$1\",\"params\":[]}" "$RPC"
}
hex2dec() { [ -n "$1" ] && printf '%d' "$1" 2>/dev/null || echo "?"; }
field() { python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('result') if '$1'=='' else d['result'].get('$1'))" 2>/dev/null; }

echo "== $(date '+%F %T') =="
echo "[geth]"
syncing=$(rpc eth_syncing | field "")
if [ "$syncing" = "False" ]; then
  echo "  동기화: 완료"
elif [ -n "$syncing" ]; then
  cur=$(rpc eth_syncing | field currentBlock); high=$(rpc eth_syncing | field highestBlock)
  echo "  동기화: 진행 중 (current=$(hex2dec "$cur"), highest=$(hex2dec "$high"))"
else
  echo "  동기화: 응답 없음 (geth 가 떠 있는지 확인: docker compose ps)"
fi
echo "  최신 블록: $(hex2dec "$(rpc eth_blockNumber | field "")")"
echo "  피어 수:   $(hex2dec "$(rpc net_peerCount | field "")")"

echo "[lighthouse]"
curl -s -m 5 "$BEACON/eth/v1/node/syncing" | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)['data']
    print(f\"  헤드 슬롯: {d['head_slot']}, 남은 거리: {d['sync_distance']}, 동기화 중: {d['is_syncing']}, EL 오프라인: {d.get('el_offline')}\")
except Exception: print('  응답 없음')"
curl -s -m 5 "$BEACON/eth/v1/node/peer_count" | python3 -c "
import sys,json
try: print('  피어 수:  ', json.load(sys.stdin)['data']['connected'])
except Exception: print('  피어 수: 응답 없음')"

echo "[디스크]"
if [ -d ./data/geth ]; then
  du -sh ./data/* 2>/dev/null | sed 's/^/  /'
  df -h . | tail -1 | awk '{print "  파일시스템 사용률: "$5" (남은 용량 "$4")"}'
else
  # Docker Desktop 처럼 Docker 볼륨에 저장한 경우: 볼륨 크기와 Docker VM 디스크 여유를 봅니다.
  docker system df -v 2>/dev/null | grep -E -- '-data ' | awk '{print "  "$1": "$NF}'
  docker exec node-exporter df -h /host 2>/dev/null | tail -1 \
    | awk '{print "  Docker VM 디스크 사용률: "$5" (남은 용량 "$4")"}'
fi

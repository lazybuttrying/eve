# 장애 연습 3가지

**동기화가 끝난 뒤**에 하세요. 동기화 중에는 원래도 지표가 불안정해서 연습으로 만든 변화와 구분하기 어렵습니다.

각 연습마다 아래 네 칸을 채우는 것이 핵심입니다. 이 네 칸이 "응답 지연과 리소스 급증을 모니터링으로 잡고, 원인을 찾아 재발을 막는다"는 직무 설명과 그대로 대응합니다.

| 칸 | 적을 내용 |
|---|---|
| 증상 | 무엇을 보고 이상하다고 알았나 (알림 이름, 패널, 로그 한 줄, 시각) |
| 원인 | 어떤 순서로 좁혔나 (어떤 명령을 쳤고 무엇을 봤나) |
| 조치 | 무엇을 해서 복구했나, 복구까지 몇 분 걸렸나 |
| 재발 방지 | 설정, 알림, 절차 중 무엇을 바꿨나 |

시작 전에 항상 기준값을 남기세요.

```bash
./scripts/check.sh | tee drill-before.txt
date '+%F %T'
```

---

## 연습 1. 클라이언트 재시작

### 1-A. 정상 재시작 (계획된 작업)

```bash
date '+%F %T'; docker compose restart geth
docker compose logs -f --since 2m lighthouse     # 다른 터미널에서
```

볼 것
- Lighthouse 로그에 실행 엔진 연결이 끊겼다는 경고가 나오는가
- `curl -s localhost:5052/eth/v1/node/syncing`의 `el_offline`이 `true`로 바뀌었다가 돌아오는가
- Grafana의 `up{job="geth"}`가 0으로 떨어지는가, TargetDown이 Pending → Firing까지 가는가 (1분 넘게 걸리면)
- 재시작 후 블록 번호가 다시 올라가기 시작할 때까지 걸린 시간

### 1-B. 비정상 종료 (갑작스러운 중단 흉내)

```bash
date '+%F %T'; docker kill geth          # SIGKILL: DB를 닫을 시간 없이 끝남
sleep 120                                # 알림이 Firing 되는 것을 확인
docker compose start geth
docker compose logs -f --since 5m geth
```

볼 것
- 1-A보다 복구가 오래 걸리는가. Geth가 시작할 때 마지막 상태를 복구하는 로그가 보이는가
- `restart: unless-stopped`인데 왜 자동으로 다시 안 떴는가 → `docker kill`은 "사용자가 멈춘 것"으로 취급되기 때문. 반대로 컨테이너 안에서 프로세스가 죽으면 자동 재시작됨. 이 차이를 직접 확인해 적어 두면 좋습니다.

> 테스트넷이라 괜찮지만, 비정상 종료를 반복하면 DB가 손상될 수 있습니다. 한두 번만 하세요.

**재발 방지 예시**: `stop_grace_period`를 충분히 두기, TargetDown 알림의 `for` 시간 조정, 재시작 절차를 문서로 남기기 (`restart` 대신 `stop` → `start`로 로그 확인).

---

## 연습 2. 피어 수 급감

`.env`에서 피어 상한을 크게 낮춰 "네트워크에서 고립된" 상황을 만듭니다.

```bash
cp .env drill-env-backup
sed -i 's/^GETH_MAXPEERS=.*/GETH_MAXPEERS=2/; s/^LH_TARGET_PEERS=.*/LH_TARGET_PEERS=5/' .env
date '+%F %T'; docker compose up -d geth lighthouse     # 바뀐 설정으로 컨테이너 재생성
```

10~20분 관찰할 것
- 피어 수 패널이 떨어지고 GethLowPeers 알림이 Firing 되는가
- 피어가 적을 때 블록 증가가 늦어지거나 슬롯 지연이 커지는가 (피어 2개로도 따라갈 수 있다면 그것도 결과입니다)
- `docker compose logs geth | grep -i peer` 에서 무엇이 보이는가

원인 좁히기 연습: 알림만 보고 원인을 모른다고 가정하고 아래 순서로 확인해 보세요.

```bash
./scripts/check.sh                               # 1) 피어 수가 정말 줄었나
docker compose ps                                # 2) 컨테이너 상태
docker inspect geth --format '{{json .Args}}'    # 3) 실행 인자에 maxpeers 가 얼마로 들어갔나
ss -tulpn | grep -E '30303|9000'                 # 4) P2P 포트가 열려 있나 (권한 필요하면 sudo)
```

복구

```bash
cp drill-env-backup .env && rm drill-env-backup
docker compose up -d geth lighthouse
```

복구 후 피어 수가 원래 수준으로 돌아오기까지 걸린 시간을 적으세요.

**선택 심화**: 설정이 아니라 실제 네트워크 문제처럼 만들고 싶다면 방화벽으로 P2P 포트를 잠시 막아 볼 수 있습니다(`ufw deny 30303` 후 `ufw delete deny 30303`). 기존 연결이 바로 끊기지 않을 수 있으니, 피어가 줄어드는 데 시간이 걸리는 것까지 관찰하세요. 다른 서비스가 쓰는 규칙을 건드리지 않도록 주의하세요.

**재발 방지 예시**: 피어 하한 알림 기준 조정, 집 서버라면 공유기 포트포워딩 추가, 설정 변경 시 `docker inspect`로 실제 인자 확인하는 절차.

---

## 연습 3. 디스크 사용량 증가

### 3-A. 증가 속도 재기 (가장 중요)

동기화가 끝난 뒤에도 체인 데이터는 계속 늘어납니다. 하루 간격으로 두 번 재서 하루 증가량을 구하세요.

```bash
date '+%F %T' >> disk-log.txt; du -s --block-size=1G data/* >> disk-log.txt; df -h . >> disk-log.txt
```

Grafana의 "디스크 남은 용량 + 3일 뒤 예측" 패널과 비교해 보고, 지금 속도면 디스크가 언제 가득 차는지 계산해 기록하세요.

### 3-B. 알림이 실제로 울리는지 확인

방법 1 (안전, 권장): 기준값을 잠시 낮춥니다.

```bash
sed -i 's/) \* 100 > 80/) * 100 > 10/' prometheus/alerts.yml    # DiskUsageHigh 기준 80% → 10%
docker compose restart prometheus
# 5분 뒤 http://localhost:9090/alerts 에서 DiskUsageHigh Firing 확인, 스크린샷
git checkout prometheus/alerts.yml && docker compose restart prometheus
```

방법 2 (실제로 채워 보기, 주의): 남은 공간이 충분할 때만, 사용률이 80%를 살짝 넘을 만큼만 큰 파일을 만듭니다.

```bash
df -B1G . | tail -1                       # 크기(Size)와 사용(Used) 확인 → 80% 넘기려면 몇 GB가 필요한지 계산
fallocate -l <계산한 크기>G ./filler.bin   # 노드가 쓸 공간을 반드시 남겨 두세요
# 알림 확인 후 즉시 삭제
rm ./filler.bin
```

> 디스크가 실제로 가득 차면 Geth DB가 손상될 수 있습니다. 방법 2는 여유가 넉넉할 때만, 끝나면 바로 지우세요.

**재발 방지 예시**: 경고 기준을 두 단계로 나누기(80% 경고, 90% 긴급), `predict_linear` 알림 유지, Docker 로그 크기 제한(compose에 `max-size: 50m`, `max-file: 5`로 이미 설정됨)이 실제로 효과가 있는지 `du -sh /var/lib/docker/containers` 로 확인, 정기 정리 절차 (`docker image prune`).

---

## 기록 예시 (연습 2를 했다고 가정한 형식 예시, 수치는 직접 채우세요)

| 칸 | 내용 |
|---|---|
| 증상 | 14:05 GethLowPeers Firing. 피어 수 패널이 24 → 2로 떨어짐 |
| 원인 | `check.sh`로 피어 2 확인 → 컨테이너는 정상 running → `docker inspect`에서 `--maxpeers=2` 확인. 설정값이 원인 |
| 조치 | `.env` 복구 후 `up -d`. 14:21 피어 20 이상 회복 (16분) |
| 재발 방지 | `.env` 변경 시 `docker inspect`로 실제 인자를 확인하는 절차 추가. 피어 하한 알림은 유지 |

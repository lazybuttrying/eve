# 이더리움 노드 운영 연습

Geth(실행 클라이언트)와 Lighthouse(합의 클라이언트)를 Docker Compose로 띄우고, Prometheus와 Grafana로 모니터링하며, 장애 연습을 기록으로 남기기 위한 저장소입니다.

| 폴더 | 언제 쓰나 | 디스크 |
|---|---|---|
| [`devnet/`](devnet/README.md) | **디스크가 부족할 때 (먼저 추천)**. 내 PC 안에 사설 PoS 네트워크를 만들어 노드 2개를 돌림 | 1GB 안팎 |
| [`sepolia-node/`](sepolia-node/README.md) | 1TB급 SSD를 쓸 수 있을 때. 공용 테스트넷 Sepolia와 실제로 동기화 | 1TB 안팎 |

두 폴더는 같은 Grafana 대시보드와 같은 알림 규칙(devnet은 피어 기준만 낮춤)을 씁니다. 장애 연습 문서와 기록 템플릿은 `sepolia-node/docs/`에 있습니다.

- [장애 연습 3가지](sepolia-node/docs/incident-drills.md)
- [작업 기록 템플릿](sepolia-node/docs/log-template.md)

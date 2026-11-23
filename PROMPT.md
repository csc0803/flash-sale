# 專案需求 (PROMPT)

## 目標
建立一個「限量搶購（秒殺）系統」，作為「文章按讚排行榜」之後的練習。重點是**高併發下的資料一致性**：不超賣、每人限購一件、同一筆訂單不重複建立，並用壓力測試的數據比較每一種寫法。

本專案的新學習重點：
1. **登入與權限**：Spring Security + JWT
2. **併發控制**：條件式更新、悲觀鎖、樂觀鎖、Redis Lua 預扣庫存，各自的取捨
3. **訊息佇列**：RabbitMQ 非同步建立訂單、重試、死信佇列（DLQ）
4. **冪等性**：同一請求或同一則訊息處理多次，結果仍然正確
5. **壓力測試**：k6，先重現超賣，再用數據證明修正有效

## 技術棧
- 後端：Spring Boot (Java 21, Maven)
- 前端：React + TypeScript (Vite)
- 資料庫：MySQL（商品、庫存、訂單的 source of truth）
- 快取 / 預扣庫存：Redis（Lua script）
- 訊息佇列：RabbitMQ
- 壓力測試：k6（用 Docker image 執行，不需另外安裝）
- 執行環境：開發時先用本機安裝的 MySQL 直接跑後端，確認可行後（Phase 11）再用 Docker Compose 容器化

## 已確認的決策（2026-11-23 確認）
| 項目 | 決策 | 說明 |
|---|---|---|
| 專案定位 | 排行榜專案的延伸，沿用同一套技術棧，新增登入、訊息佇列、壓力測試 | |
| 情境 | 限量商品在指定時間開賣，使用者登入後搶購，每人每個商品限購一件 | |
| 專案位置 | `D:\workspace\flash-sale`，獨立 git repository；GitHub：`csc0803/flash-sale`（public） | |
| 開發環境 | 先在本機開發：後端連本機 MySQL（3306），使用專案專用帳號 `flashsale@localhost`，只授予 `flashsaledb.*` 權限。全部功能在本機確認 OK 後再容器化 | 帳號密碼不寫進 repo |
| Schema 管理 | `db/01-init.sql` 手動在 Workbench 執行，不使用 Flyway；`spring.jpa.hibernate.ddl-auto` 設 `validate` | 之後需要頻繁改 schema 時再考慮導入 Flyway |
| 登入方式 | 帳號密碼註冊/登入，密碼用 BCrypt，登入後發 JWT（access token，無 refresh token）。JWT 用 Spring Security OAuth2 Resource Server（`JwtEncoder` 發 token、`JwtDecoder` 驗證），不自己寫 filter | 角色分 `USER` / `ADMIN`，ADMIN 才能建立商品、設定庫存。refresh token、OAuth 列為 stretch |
| 訊息佇列 | RabbitMQ（不用 Kafka） | 秒殺下單是「工作佇列」情境，RabbitMQ 的 ack、重試、DLQ、延遲訊息（TTL + DLX）都比 Kafka 直觀；Kafka 適合事件串流，之後可另開專案練 |
| 下單策略可切換 | `flashsale.order-strategy`：`naive` / `conditional` / `pessimistic` / `optimistic` / `redis` / `mq` | 沿用排行榜 `like-write-mode` 的作法（`@ConditionalOnProperty` 選 bean），同一個 API、同一份壓測腳本，只換設定就能比較 |
| 限購一件 | MySQL `orders` 加 `UNIQUE(user_id, product_id)` 當最後防線；Redis 策略另用 Set 提前擋 | 只靠應用程式判斷「買過沒」在併發下會失效，一定要有 DB 約束 |
| 冪等性 | 下單請求帶 `Idempotency-Key` header；MQ consumer 以訂單編號 + 唯一約束去重 | MQ 是 at-least-once，consumer 必須能承受重複訊息 |
| 付款 | 不串金流，提供模擬付款 API（`POST /api/orders/{id}/pay`） | 重點是「逾時未付款取消並回補庫存」的流程 |
| 訂單逾時 | 預設 5 分鐘未付款自動取消（可設定，測試時調短），用 RabbitMQ TTL + DLX 做延遲訊息 | 另一種做法是排程掃描，會在 Phase 9 比較 |
| Port 配置 | 本機開發：MySQL 3306（本機安裝）、backend 8081、frontend 5174。容器化後：MySQL 3308、Redis 6380、RabbitMQ 5673 / 管理介面 15673 | backend / frontend 刻意避開排行榜專案（8080 / 5173）；容器化後的 port 也避開排行榜專案（3307 / 6379），兩個專案可同時啟動 |
| 測試 | 每個 Phase 完成時一併寫測試，不再另開「後端測試」階段 | 排行榜專案最後才補測試，改動時較難確認沒弄壞。Redis、RabbitMQ、MySQL 鎖的行為用 Testcontainers 測真的服務 |
| Spring Boot 版本 | 4.2.0（產生專案時 Spring Initializr 的預設穩定版） | |
| 套件名稱 | `com.chun.backend`（groupId `com.chun`、artifactId `backend`，沿用 Initializr 產生的名稱） | |

## 尚未決定
| 項目 | 何時決定 | 說明 |
|---|---|---|
| Redis / RabbitMQ 執行方式 | Phase 6（Redis）、Phase 8（RabbitMQ）開始前 | Redis 官方不支援 Windows（需 WSL 或 Memurai）；RabbitMQ 有 Windows 安裝檔但需先裝 Erlang。也可以只把這兩個先用 Docker 跑 |

完整分階段任務規劃請見 [PROGRESS.md](./PROGRESS.md)。

## 本機環境資訊（2026-11-23 Phase 0 確認）
- Java: 21.0.11
- Node: v24.13.1
- npm: 11.8.0
- Docker: 29.9.2（Testcontainers、k6、Phase 11 容器化會用到）
- MySQL：本機安裝 9.7.4 LTS（2026-11-23 從 8.0 重新安裝，8.0 已 EOL），port 3306，Windows 服務 `MySQL97`，用 MySQL Workbench 管理
- Maven：使用 Maven Wrapper (mvnw)
- GitHub CLI：2.94.0

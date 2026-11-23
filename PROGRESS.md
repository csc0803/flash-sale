# 專案進度 (PROGRESS)

最後更新：2026-11-23

## 目前狀態
2026-11-23：專案規劃完成。已建立 `D:\workspace\flash-sale`（git init、`.gitignore` 沿用排行榜專案）、`PROMPT.md`、`PROGRESS.md`。下一步：確認 PROMPT.md 的預設假設，進入 Phase 0。

2026-11-23：調整開發環境：先在本機用本機安裝的 MySQL（3306）開發，確認可行後才在 Phase 11 容器化。`docker-compose.yml` 移到 Phase 11；Redis / RabbitMQ 的執行方式在 Phase 6 / Phase 8 開始前再決定。

2026-11-23：**Phase 0 完成**。PROMPT.md 的預設假設全部確認，第一個 commit 已 push 到 GitHub `csc0803/flash-sale`。`backend/` 已用 Initializr 產生，`db/01-init.sql` 已寫好。下一步：Phase 1，在本機 MySQL 執行建表 script、設定 `application-local.yaml`，讓後端連上 MySQL 啟動成功。

2026-11-23：Phase 1 大部分完成。本機 MySQL 從 8.0（已 EOL）換成 9.7.4 LTS，建好 `flashsaledb` 與 `flashsale` 帳號、執行 `db/01-init.sql`；後端改用 port 8081（8080 被排行榜專案佔用），用 local profile 啟動成功。剩下 Testcontainers 對齊本機 schema，等 Phase 2 entity 在本機驗證後再做。

## 專案結構（規劃）
```
flash-sale/
├── PROMPT.md
├── PROGRESS.md
├── README.md
├── docker-compose.yml        # Phase 11 才建立：MySQL + Redis + RabbitMQ + backend + frontend
├── db/                       # 建表 SQL（本機開發時在 Workbench 手動執行）
├── loadtest/                 # k6 壓測腳本與結果
├── backend/                  # Spring Boot (Maven)
└── frontend/                 # React (Vite)
```

## 資料模型（規劃）
| Table | 主要欄位 | 重點 |
|---|---|---|
| `users` | id, username, password_hash, role, created_at | `username` UNIQUE |
| `product` | id, name, price, stock, version, sale_start_at, sale_end_at | `version` 給樂觀鎖用；`stock` 不可小於 0 |
| `orders` | id, order_no, user_id, product_id, status, created_at, paid_at | `UNIQUE(user_id, product_id)` 限購一件；`order_no` UNIQUE 給冪等用；status：`PENDING` / `PAID` / `CANCELLED` |

## 下單策略比較（Phase 4～8 逐步完成，結果填入此表與 README）
| 策略 | 做法 | 預期問題 / 取捨 | 壓測結果 |
|---|---|---|---|
| `naive` | 讀庫存 → Java 判斷 > 0 → 存回 stock - 1 | 超賣 | 待測 |
| `conditional` | `UPDATE ... SET stock = stock - 1 WHERE id = ? AND stock > 0` | 正確且簡單，但所有請求都打 MySQL | 待測 |
| `pessimistic` | `SELECT ... FOR UPDATE` 再扣 | 正確，但排隊等鎖，吞吐量低 | 待測 |
| `optimistic` | 比對 `version`，失敗重試 | 搶同一商品時大量衝突、重試 | 待測 |
| `redis` | Lua 原子預扣庫存 + 檢查是否買過，成功才寫 MySQL | 快，但要處理 Redis 與 MySQL 不一致 | 待測 |
| `mq` | Lua 預扣成功 → 送 RabbitMQ → consumer 建訂單，前端查詢結果 | 回應最快，但變成最終一致、要處理重複訊息與失敗補償 | 待測 |

---

## Phase 0：專案初始化與環境準備
- [x] 確定專案主題與技術棧
- [x] 建立專案目錄、`git init`、`.gitignore`
- [x] 建立 `PROMPT.md`、`PROGRESS.md`
- [x] 確認 PROMPT.md 的預設假設（全部確認；JWT 改用 OAuth2 Resource Server、套件名稱維持 `com.chun.backend`、不使用 Flyway）
- [x] 再次確認本機環境版本（Java 21.0.11、Node v24.13.1、npm 11.8.0、Docker 29.9.2、gh 2.94.0）
- [x] 建立第一個 git commit，建立 GitHub remote（`csc0803/flash-sale`，public）

## Phase 1：後端骨架與基礎設施
- [x] 用 Spring Initializr 產生 `backend/`（Spring Boot 4.2.0；Web、Data JPA、Validation、MySQL Driver、Data Redis、RabbitMQ、Security、OAuth2 Resource Server、Lombok、Testcontainers）
- [x] 本機 MySQL（MySQL Workbench）：建立 `flashsaledb`（utf8mb4）與專用帳號 `flashsale@localhost`，只授予 `flashsaledb.*` 權限（帳號密碼不寫進 repo）。MySQL 8.0 已 EOL，改為重新安裝 9.7.4 LTS
- [x] `db/01-init.sql`：`users` / `product` / `orders` table 與約束，在 Workbench 用 `flashsale` 帳號執行（已在 9.7.4 執行，約束確認無誤）
- [x] profile 設定：`application.yaml`（`server.port: 8081`、`ddl-auto: validate`）+ `application-local.yaml`（密碼，不進 git）+ `application-local.yaml.example`（範本）
- [x] 確認後端可連上本機 MySQL 並啟動成功（`-Dspring-boot.run.profiles=local`）
- [ ] 建立 Testcontainers 共用測試設定（MySQL / Redis / RabbitMQ；Initializr 沒有帶 Redis 的 Testcontainers 模組，用 `GenericContainer` 或另外加）。目前 `./mvnw test` 可通過。**延後到 entity 在本機確認後**：MySQL 容器改用 `mysql:9.7`，資料庫名稱 / 帳號 / 時區（+08:00）/ `lower_case_table_names=1` 對齊本機，並掛載 `db/01-init.sql` 自動建表；Redis、RabbitMQ 也固定版本

## Phase 2：登入與權限（Spring Security + JWT）
- [ ] `User` entity、`UserRepository`
- [ ] `POST /api/auth/register`（BCrypt 雜湊密碼、帳號重複回 409）
- [ ] `POST /api/auth/login`（驗證成功回 JWT）
- [ ] JWT：用 OAuth2 Resource Server 的 `JwtEncoder` 發 token、`JwtDecoder` 驗證 `Authorization: Bearer <token>`，把 JWT 裡的角色轉成 Spring Security 的權限
- [ ] 權限規則：商品查詢公開；下單需登入；建立商品需 `ADMIN`
- [ ] 401 / 403 錯誤格式與 `GlobalExceptionHandler` 一致
- [ ] 測試：註冊、登入、token 過期或竄改、權限不足
- [ ] 理解：session 與 JWT 的差異、JWT 無法主動作廢的問題

## Phase 3：商品 API
- [ ] `Product` entity、`ProductRepository`
- [ ] `GET /api/products`、`GET /api/products/{id}`（含剩餘庫存、開賣時間）
- [ ] `POST /api/products`（ADMIN）
- [ ] 測試資料 seed：一個 ADMIN、壓測用的大量測試帳號
- [ ] 測試

## Phase 4：最簡單的下單，與重現超賣
- [ ] `Order` entity、`OrderRepository`
- [ ] `POST /api/products/{id}/orders`，下單策略介面 `OrderStrategy` + `naive` 實作（先查庫存、Java 判斷、再存回）
- [ ] 檢查開賣時間、商品存在、庫存不足回 409、已買過回 409
- [ ] `GET /api/orders`（自己的訂單）、`GET /api/orders/{id}`
- [ ] `loadtest/order.js`：k6 腳本，N 個不同使用者同時搶庫存 100 的商品（k6 用 Docker 跑、後端在本機時，目標網址要用 `host.docker.internal:8081`，不是 `localhost`）
- [ ] 壓測驗證：成立的訂單數 > 100（超賣），`stock` 可能變負或與訂單數不符
- [ ] 理解：為什麼 Java 層「先檢查再寫入」在併發下會失敗（race condition）

## Phase 5：用 MySQL 解決超賣（三種做法比較）
- [ ] `conditional`：單一 SQL 條件式扣庫存，更新 0 筆即售完
- [ ] `pessimistic`：`@Lock(PESSIMISTIC_WRITE)`（`SELECT ... FOR UPDATE`）
- [ ] `optimistic`：`@Version`，衝突時有限次數重試
- [ ] 限購一件：靠 `UNIQUE(user_id, product_id)`，捕捉唯一約束例外回 409，並讓扣庫存一起 rollback
- [ ] 三種都用同一份 k6 腳本壓測：確認不超賣，記錄 RPS、p95 延遲、錯誤率，填入策略比較表
- [ ] 理解：交易隔離等級、行鎖、死結風險

## Phase 6：Idempotency-Key 防重複送出
- [ ] 決定 Redis 執行方式（WSL / Memurai / 單獨用 Docker 跑），`application-local.yaml` 加上連線設定並確認連得上
- [ ] 下單請求帶 `Idempotency-Key`（前端產生），Redis `SET NX` 記錄處理中/已完成的結果
- [ ] 同一個 key 重送回相同結果，不重複扣庫存
- [ ] 測試：同一 key 併發送兩次、處理中送第二次
- [ ] 理解：冪等性 vs 限購一件，兩者解決的問題不同

## Phase 7：Redis Lua 預扣庫存（`redis` 策略）
- [ ] 開賣前把庫存載入 Redis（`flashsale:product:{id}:stock`）
- [ ] Lua script：檢查庫存 > 0 且使用者沒買過（Set）→ `DECR` + `SADD`，回傳結果碼
- [ ] Lua 成功才寫 MySQL（條件式扣庫存 + 建訂單）；MySQL 失敗要把 Redis 補回
- [ ] 售完後的請求直接在 Redis 擋掉，不打 MySQL
- [ ] 壓測比較，並確認 Redis 與 MySQL 最終庫存一致
- [ ] 測試：Testcontainers 對真的 Redis 測 Lua
- [ ] 理解：Redis 與 MySQL 雙寫不一致的情境，與對帳機制

## Phase 8：RabbitMQ 非同步下單（`mq` 策略）
- [ ] 決定 RabbitMQ 執行方式（Windows 安裝 + Erlang / 單獨用 Docker 跑），開啟 management 介面，`application-local.yaml` 加上連線設定並確認連得上
- [ ] Lua 預扣成功 → 發訊息到 `order.create` queue，API 立即回 202 + 訂單編號
- [ ] consumer 建訂單：手動 ack、以 `order_no` 唯一約束保證重複訊息不會建兩筆
- [ ] 失敗重試有上限，超過送 DLQ；DLQ 的訊息要回補 Redis 庫存
- [ ] `GET /api/orders/by-no/{orderNo}`：前端輪詢下單結果（處理中 / 成功 / 失敗）
- [ ] publisher confirm：確認訊息真的送到 broker
- [ ] 壓測比較，並測試 consumer 停機、MySQL 停機時的行為
- [ ] 測試：Testcontainers RabbitMQ
- [ ] 理解：at-least-once、最終一致性、為什麼 consumer 一定要冪等

## Phase 9：訂單逾時取消與付款
- [ ] `POST /api/orders/{id}/pay`：模擬付款，`PENDING` → `PAID`
- [ ] 建單時送延遲訊息（RabbitMQ TTL + DLX），到期仍是 `PENDING` 就改 `CANCELLED` 並回補庫存（MySQL + Redis）
- [ ] 付款與逾時取消同時發生的併發處理（條件式更新狀態）
- [ ] 取消後同一使用者可以再買（限購約束要配合調整）
- [ ] 測試，並與「排程掃描逾時訂單」的做法比較

## Phase 10：前端
- [ ] Vite + React + TypeScript + Bootstrap 骨架
- [ ] 登入 / 註冊頁，token 存放與過期處理
- [ ] 商品列表與詳情，開賣倒數
- [ ] 搶購按鈕：送出中鎖定、帶 Idempotency-Key、`mq` 策略時輪詢結果
- [ ] 我的訂單：付款、倒數、逾時狀態
- [ ] 前端測試（Vitest + React Testing Library）

## Phase 11：整合、容器化與文件
- [ ] `docker-compose.yml`：MySQL（3308）、Redis（6380）、RabbitMQ（5673 / 15673，含 management 介面），都加 healthcheck
- [ ] MySQL 帳號改由 compose 建立（`MYSQL_DATABASE` / `MYSQL_USER` / `MYSQL_PASSWORD`，密碼放 `.env`），`db/` 的 SQL 掛進 `/docker-entrypoint-initdb.d` 自動建表
- [ ] `application-docker.yaml`：容器內的連線設定（用 service 名稱連線，不是 `localhost`）
- [ ] backend / frontend Dockerfile，`docker compose up -d --build` 一鍵啟動
- [ ] 端對端驗證（瀏覽器實際搶購流程）
- [ ] 完整壓測：六種策略用同樣條件重跑，結果整理成表格與說明
- [ ] README：啟動方式、架構圖、資料模型、API 規格、策略比較與結論

## Phase 12（Stretch）
- [ ] GitHub Actions CI：push 時跑前後端測試
- [ ] 限流：每個使用者每秒 N 次（Redis Lua）
- [ ] refresh token、登出（token 黑名單）
- [ ] 監控：Spring Boot Actuator + Prometheus + Grafana 看壓測時的指標
- [ ] 多個 backend instance 一起跑，驗證各策略在多實例下是否仍正確

## 下一步
Phase 2：建立 `User` entity，用 local profile 啟動確認 `ddl-auto: validate` 通過；接著把 Testcontainers 的 MySQL 對齊本機（見 Phase 1 最後一項），再寫註冊 / 登入與 JWT。

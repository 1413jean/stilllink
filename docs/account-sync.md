# 帳號同步：Supabase＋Google／Apple 登入設定

Mac 和 iPhone 用同一個 Supabase 專案。登入同一個帳號，命盤、備註、照片、頭貼、偏好設定就會同步。
App 端的程式已經寫好（`apps/apple/Sources/StillLink/Sync/`），只差下面這些後台設定。

## 1. 建 Supabase 專案（約 5 分鐘）

1. 到 https://supabase.com 登入（可以用 GitHub），按 **New project**
   - Name：`stilllink`
   - Region：**Northeast Asia (Tokyo)** 或 Southeast Asia (Singapore)，離台灣近比較快
   - Database password：自己存好（App 用不到）
2. 左邊 **SQL Editor** → 新增 → 把 `backend/supabase/schema.sql` 整份貼上 → **Run**
3. 左邊 **Authentication → URL Configuration → Redirect URLs** → Add URL：`stilllink://auth-callback`
4. 左邊 **Project Settings → API**，把這兩個給我：
   - **Project URL**（像 `https://abcdefgh.supabase.co`）
   - **anon public** key（很長一串，`eyJ…` 開頭）

> anon key 是公開金鑰，本來就會放進 App。**不要**給我 `service_role` key（那把會繞過所有權限）。

## 2. Google 登入（不需要付費帳號，可以先做）

1. 到 https://console.cloud.google.com → 上方建一個新專案 `StillLink`
2. **APIs & Services → OAuth consent screen**
   - User Type：External
   - App name：StillLink；User support email、Developer contact：jean@jeanui.com
   - 其他先空著，存檔；**Publishing status 按 Publish App**（不然只有測試帳號能登入）
3. **APIs & Services → Credentials → Create Credentials → OAuth client ID**
   - Application type：**Web application**（Supabase 是用網頁流程，不是選 iOS）
   - Authorized redirect URIs：`https://<你的專案代號>.supabase.co/auth/v1/callback`
   - 建好後複製 **Client ID** 和 **Client secret**
4. 回 Supabase：**Authentication → Sign In / Providers → Google** → 打開，貼上 Client ID、Client secret → Save

## 3. Apple 登入（加入 Apple Developer Program 之後）

1. https://developer.apple.com/account → **Certificates, Identifiers & Profiles**
2. **Identifiers → ＋ → Services IDs**
   - Description：StillLink Sign In；Identifier：`app.stilllink.signin`
   - 建好後點進去，勾 **Sign in with Apple → Configure**
     - Primary App ID：選 StillLink 的 App ID（沒有就先在 Identifiers 建一個 `app.stilllink.ios`，勾 Sign in with Apple）
     - Domains：`<你的專案代號>.supabase.co`
     - Return URLs：`https://<你的專案代號>.supabase.co/auth/v1/callback`
3. **Keys → ＋**：名字 `StillLink Sign in with Apple`，勾 **Sign in with Apple**（Configure 選同一個 App ID）→ 下載 `.p8`（只能下載一次，存好），記下 **Key ID**
4. 右上角記下 **Team ID**
5. 回 Supabase：**Authentication → Sign In / Providers → Apple** → 打開
   - Client IDs：`app.stilllink.signin`
   - Secret Key：用 Team ID、Key ID、.p8 產生（把這三個給我，我幫你產生；這把每 6 個月要重產一次）

## 4. 給我之後我會做的

- 把 Project URL、anon key 填進 `CloudConfig.swift`
- Mac、iPhone 各登入一次，確認：新增／修改／刪除命盤、照片、偏好設定兩邊都會同步
- 隱私權政策補上「資料存放在 Supabase（雲端）」

## 同步規則（給之後維護的人）

- 每張命盤一列（整張存成 jsonb），各自比修改時間，最後改的贏；刪除會標記 `deleted` 同步到其他裝置
- 第一次在某台裝置登入：本機已有的命盤會合併上去，不會蓋掉雲端
- 登出：只清這台的登入狀態，本機資料保留
- Mac「清空所有資料」會先自動登出，避免把雲端也清空
- 照片／頭貼存在私有 bucket `media/<使用者 id>/<檔名>`，只有本人讀得到
- 刪除帳號：App 裡呼叫 `delete_my_account()`，雲端資料一起刪（App Store 規定要有）
- 沒有同步的：星曜筆記的自訂內容、日記（之後要再加）

-- StillLink 帳號同步：Supabase 資料庫結構
-- 用法：Supabase 後台 → SQL Editor → 貼上整份 → Run（可以重複執行）
--
-- 設計：
-- - 每張命盤一列，整張 Person 存成 jsonb（App 端的資料結構改了不用跟著改資料表）
-- - updated_at：App 端寫入的修改時間，用來判斷誰比較新（最後寫入的贏）
-- - server_at：伺服器收到的時間，App 拉資料時用它當游標（不受各裝置時鐘誤差影響）
-- - deleted：刪除也要同步到其他裝置，所以不真的刪，標記成 true
-- - Row Level Security：每個人只能讀寫自己的資料（user_id = 登入者）

create table if not exists public.people (
  id          uuid primary key,
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  data        jsonb not null,
  updated_at  timestamptz not null,
  server_at   timestamptz not null default now(),
  deleted     boolean not null default false
);
create index if not exists people_user_server on public.people (user_id, server_at);

-- 偏好設定（名字、哪張是自己、命盤設定、排序、外觀…）：一個帳號一列
create table if not exists public.prefs (
  user_id     uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  data        jsonb not null,
  updated_at  timestamptz not null,
  server_at   timestamptz not null default now()
);

-- 每次寫入都更新 server_at
create or replace function public.touch_server_at() returns trigger language plpgsql as $$
begin new.server_at := now(); return new; end $$;
drop trigger if exists people_touch on public.people;
create trigger people_touch before insert or update on public.people for each row execute function public.touch_server_at();
drop trigger if exists prefs_touch on public.prefs;
create trigger prefs_touch before insert or update on public.prefs for each row execute function public.touch_server_at();

alter table public.people enable row level security;
alter table public.prefs enable row level security;

drop policy if exists "own people" on public.people;
create policy "own people" on public.people for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists "own prefs" on public.prefs;
create policy "own prefs" on public.prefs for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- 照片、頭貼：私有 bucket「media」，路徑是「使用者 id/檔名」，只能存取自己資料夾
insert into storage.buckets (id, name, public) values ('media', 'media', false)
  on conflict (id) do nothing;

drop policy if exists "own media read" on storage.objects;
create policy "own media read" on storage.objects for select
  using (bucket_id = 'media' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "own media write" on storage.objects;
create policy "own media write" on storage.objects for insert
  with check (bucket_id = 'media' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "own media update" on storage.objects;
create policy "own media update" on storage.objects for update
  using (bucket_id = 'media' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "own media delete" on storage.objects;
create policy "own media delete" on storage.objects for delete
  using (bucket_id = 'media' and (storage.foldername(name))[1] = auth.uid()::text);

-- 刪除帳號（App Store 規定有登入就要能在 App 裡刪帳號）：使用者自己呼叫，連同資料一起刪
create or replace function public.delete_my_account() returns void
language plpgsql security definer set search_path = public as $$
begin
  delete from storage.objects where bucket_id = 'media' and (storage.foldername(name))[1] = auth.uid()::text;
  delete from auth.users where id = auth.uid();
end $$;
revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;

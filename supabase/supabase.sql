-- YDS Arapça: hesap, eşleşme ve liderlik tablosu
-- Supabase panelinde SQL Editor > New query'ye yapıştırıp bir kez çalıştır.
-- Birden fazla kez çalıştırmak zararsızdır.

-- ========== 1) Liderlik tablosu ==========
create table if not exists public.scores (
  user_id       uuid primary key references auth.users(id) on delete cascade,
  nick          text not null,
  week_key      text not null default '',
  week_correct  int  not null default 0 check (week_correct >= 0),
  total_correct int  not null default 0 check (total_correct >= 0),
  streak        int  not null default 0 check (streak >= 0),
  badges        int  not null default 0 check (badges >= 0),
  updated_at    timestamptz not null default now(),
  constraint scores_nick_len check (char_length(nick) between 3 and 16)
);

-- Aynı takma ad (büyük/küçük harf fark etmeksizin) iki kişide olamaz
create unique index if not exists scores_nick_lower on public.scores (lower(nick));

alter table public.scores enable row level security;

-- Herkes sıralamayı okuyabilir; doğrudan yazma yok, yalnızca aşağıdaki fonksiyonlar yazar
drop policy if exists "herkes okuyabilir" on public.scores;
create policy "herkes okuyabilir" on public.scores
  for select to anon, authenticated using (true);
revoke insert, update, delete on public.scores from anon, authenticated;
grant select on public.scores to anon, authenticated;

-- Puan gönderme: değerleri sınırlar (hileyi zorlaştırır, tamamen engellemez)
create or replace function public.submit_score(
  p_nick text, p_week text, p_week_correct int, p_total int, p_streak int, p_badges int
) returns void
language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  n   text := btrim(regexp_replace(coalesce(p_nick, ''), '\s+', ' ', 'g'));
  old public.scores%rowtype;
  secs numeric;
  allow int;
begin
  if uid is null then raise exception 'giris gerekli'; end if;
  if char_length(n) not between 3 and 16 or n ~ '[<>&"''`]' then
    raise exception 'gecersiz takma ad';
  end if;
  if p_week !~ '^\d{4}-\d{2}-\d{2}$' then raise exception 'gecersiz hafta'; end if;
  if p_week_correct < 0 or p_total < 0 or p_streak < 0 or p_badges < 0
     or p_week_correct > 2000 or p_total > 2000 or p_streak > 1000 or p_badges > 100 then
    raise exception 'gecersiz deger';
  end if;

  select * into old from public.scores where user_id = uid;

  if not found then
    -- Yeni kayıt: başlangıç değerleri sınırlı (başka cihazdaki ilerlemeyi taşıyan gerçek kullanıcılar da olabilir)
    insert into public.scores(user_id, nick, week_key, week_correct, total_correct, streak, badges)
    values (uid, n, p_week, least(p_week_correct, 1500), least(p_total, 1500),
            least(p_streak, 60), least(p_badges, 100));
    return;
  end if;

  -- Son güncellemeden bu yana geçen süreye göre izin verilen artış (dakikada yaklaşık 15 doğru)
  secs  := greatest(extract(epoch from (now() - old.updated_at)), 0);
  allow := 20 + floor(secs / 4)::int;

  p_total := greatest(old.total_correct, least(p_total, old.total_correct + allow));
  if p_week = old.week_key then
    p_week_correct := greatest(old.week_correct, least(p_week_correct, old.week_correct + allow));
  else
    p_week_correct := least(p_week_correct, allow);
  end if;
  p_streak := greatest(old.streak, least(p_streak, old.streak + 1 + floor(secs / 86400)::int));

  update public.scores
     set nick = n, week_key = p_week, week_correct = p_week_correct,
         total_correct = p_total, streak = p_streak,
         badges = least(p_badges, 100), updated_at = now()
   where user_id = uid;
end;
$$;

-- Kaydı silme (kullanıcı "Ayrıl ve kaydımı sil" dediğinde)
create or replace function public.delete_score() returns void
language sql security definer set search_path = public as $$
  delete from public.scores where user_id = auth.uid();
$$;

revoke all on function public.submit_score(text, text, int, int, int, int) from public, anon;
revoke all on function public.delete_score() from public, anon;
grant execute on function public.submit_score(text, text, int, int, int, int) to authenticated;
grant execute on function public.delete_score() to authenticated;

-- ========== 2) Cihazlar arası eşleşme ==========
-- Her kullanıcının tek bir satırı var; yalnızca kendi satırını okuyabilir ve yazabilir.
create table if not exists public.user_data (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  data       jsonb not null,
  updated_at timestamptz not null default now(),
  constraint user_data_size check (octet_length(data::text) < 1500000)
);

alter table public.user_data enable row level security;
revoke all on public.user_data from anon;

drop policy if exists "kendi verisini oku" on public.user_data;
drop policy if exists "kendi verisini ekle" on public.user_data;
drop policy if exists "kendi verisini guncelle" on public.user_data;
drop policy if exists "kendi verisini sil" on public.user_data;
create policy "kendi verisini oku" on public.user_data
  for select to authenticated using (auth.uid() = user_id);
create policy "kendi verisini ekle" on public.user_data
  for insert to authenticated with check (auth.uid() = user_id);
create policy "kendi verisini guncelle" on public.user_data
  for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "kendi verisini sil" on public.user_data
  for delete to authenticated using (auth.uid() = user_id);

create or replace function public.touch_user_data() returns trigger
language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end;
$$;
drop trigger if exists user_data_touch on public.user_data;
create trigger user_data_touch before insert or update on public.user_data
  for each row execute function public.touch_user_data();

-- ========== 3) Hesap silme ==========
-- Hesap, eşleşme verisi ve liderlik kaydı kalıcı olarak silinir (bağlı tablolar "on delete cascade" ile gider).
create or replace function public.delete_account() returns void
language plpgsql security definer set search_path = public, auth as $$
begin
  if auth.uid() is null then raise exception 'giris gerekli'; end if;
  delete from auth.users where id = auth.uid();
end;
$$;

revoke all on function public.delete_account() from public, anon;
grant execute on function public.delete_account() to authenticated;

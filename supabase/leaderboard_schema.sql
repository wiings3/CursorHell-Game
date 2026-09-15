create table if not exists public.endless_leaderboard (
  player_id uuid primary key,
  player_secret uuid not null,
  callsign text not null check (char_length(callsign) between 1 and 16),
  best_survival_ms bigint not null default 0,
  survival_score bigint not null default 0,
  survival_phase integer not null default 0,
  best_score bigint not null default 0,
  score_survival_ms bigint not null default 0,
  score_phase integer not null default 0,
  updated_at timestamptz not null default now()
);

alter table public.endless_leaderboard enable row level security;
revoke all on public.endless_leaderboard from anon, authenticated;

drop view if exists public.endless_leaderboard_public;
create view public.endless_leaderboard_public as
select
  player_id,
  callsign,
  best_survival_ms,
  survival_score,
  survival_phase,
  best_score,
  score_survival_ms,
  score_phase,
  updated_at
from public.endless_leaderboard;

grant select on public.endless_leaderboard_public to anon, authenticated;

create or replace function public.submit_endless_result(
  p_player_id uuid,
  p_player_secret uuid,
  p_callsign text,
  p_survival_ms bigint,
  p_score bigint,
  p_phase integer
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  clean_name text := btrim(p_callsign);
  max_reachable_phase integer;
  cycle_ms bigint;
  cycle_index bigint;
  cycle_time bigint;
  normal_block_ms bigint := 60000;
  existing_secret uuid;
begin
  if clean_name !~ '^[A-Za-z0-9 _.-]{1,16}$' then
    raise exception 'Invalid callsign';
  end if;
  if p_survival_ms < 0 or p_survival_ms > 86400000 then
    raise exception 'Invalid survival time';
  end if;
  if p_score < 0 or p_score > 50000 + ((p_survival_ms / 1000) * 50000) then
    raise exception 'Invalid score';
  end if;

  if p_survival_ms < 5000 then
    max_reachable_phase := 0;
  else
    cycle_ms := p_survival_ms - 5000;
    cycle_index := cycle_ms / 95000;
    cycle_time := cycle_ms % 95000;
    if cycle_time < normal_block_ms then
      max_reachable_phase := (cycle_index * 5 + (cycle_time / 12000) + 1)::integer;
    else
      max_reachable_phase := (cycle_index * 5 + 5)::integer;
    end if;
  end if;
  if p_phase < 0 or p_phase > max_reachable_phase + 1 then
    raise exception 'Invalid phase for survival time';
  end if;

  select player_secret into existing_secret
  from public.endless_leaderboard
  where player_id = p_player_id;

  if existing_secret is not null and existing_secret <> p_player_secret then
    raise exception 'Invalid submission token';
  end if;

  insert into public.endless_leaderboard as l (
    player_id, player_secret, callsign,
    best_survival_ms, survival_score, survival_phase,
    best_score, score_survival_ms, score_phase,
    updated_at
  ) values (
    p_player_id, p_player_secret, clean_name,
    p_survival_ms, p_score, p_phase,
    p_score, p_survival_ms, p_phase,
    now()
  )
  on conflict (player_id) do update set
    callsign = excluded.callsign,
    best_survival_ms = greatest(l.best_survival_ms, excluded.best_survival_ms),
    survival_score = case when excluded.best_survival_ms > l.best_survival_ms
      or (excluded.best_survival_ms = l.best_survival_ms and excluded.survival_score > l.survival_score)
      then excluded.survival_score else l.survival_score end,
    survival_phase = case when excluded.best_survival_ms > l.best_survival_ms
      or (excluded.best_survival_ms = l.best_survival_ms and excluded.survival_score > l.survival_score)
      then excluded.survival_phase else l.survival_phase end,
    best_score = greatest(l.best_score, excluded.best_score),
    score_survival_ms = case when excluded.best_score > l.best_score
      or (excluded.best_score = l.best_score and excluded.score_survival_ms > l.score_survival_ms)
      then excluded.score_survival_ms else l.score_survival_ms end,
    score_phase = case when excluded.best_score > l.best_score
      or (excluded.best_score = l.best_score and excluded.score_survival_ms > l.score_survival_ms)
      then excluded.score_phase else l.score_phase end,
    updated_at = now();

  return jsonb_build_object('ok', true);
end;
$$;

revoke all on function public.submit_endless_result(uuid,uuid,text,bigint,bigint,integer) from public;
grant execute on function public.submit_endless_result(uuid,uuid,text,bigint,bigint,integer) to anon, authenticated;

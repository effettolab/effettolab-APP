alter table public.orders
  add column if not exists completed_at timestamptz,
  add column if not exists completed_by uuid references auth.users(id) on delete set null;

create or replace function public.track_order_completion()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if NEW.status='Listo' and (TG_OP='INSERT' or OLD.status is distinct from 'Listo') then
    NEW.completed_at := now();
    NEW.completed_by := auth.uid();
  end if;
  return NEW;
end;
$$;
drop trigger if exists trg_track_order_completion on public.orders;
create trigger trg_track_order_completion
before insert or update of status on public.orders
for each row execute function public.track_order_completion();

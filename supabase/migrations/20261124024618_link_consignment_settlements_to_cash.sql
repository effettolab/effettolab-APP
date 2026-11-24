alter table public.expenses
  drop constraint if exists expenses_category_check,
  add constraint expenses_category_check
    check (category = any (array['Operacional'::text,'Personal'::text,'Comisión técnica'::text,'Consignación'::text]));

alter table public.expenses
  add column if not exists consignment_settlement_id bigint
  references public.consignment_settlements(id) on delete restrict;

create unique index if not exists expenses_consignment_settlement_unique
  on public.expenses(consignment_settlement_id)
  where consignment_settlement_id is not null;

create or replace function public.register_consignment_settlement(
  p_consignor_name text,
  p_sale_ids bigint[],
  p_paid_on date,
  p_method text,
  p_notes text default null
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id bigint;
  v_total numeric(12,2);
  v_count integer;
  v_expected integer;
  v_paid_on date;
begin
  if auth.uid() is null or not public.has_perm('portafolio') then
    raise exception 'No tienes permiso para registrar liquidaciones de consignación';
  end if;
  if nullif(trim(p_consignor_name),'') is null then raise exception 'Falta el nombre del consignador'; end if;
  if coalesce(array_length(p_sale_ids,1),0) = 0 then raise exception 'Selecciona al menos una venta pendiente'; end if;
  if p_method not in ('Efectivo','Transferencia','Tarjeta','Otro') then raise exception 'Método de pago inválido'; end if;

  perform 1 from public.consignment_sales
   where id = any(p_sale_ids)
     and status = 'Pendiente'
     and lower(trim(consignor_name)) = lower(trim(p_consignor_name))
   for update;

  select count(*), coalesce(sum(owner_amount),0)
    into v_count, v_total
  from public.consignment_sales
  where id = any(p_sale_ids)
    and status = 'Pendiente'
    and lower(trim(consignor_name)) = lower(trim(p_consignor_name));

  v_expected := cardinality(p_sale_ids);
  if v_count <> v_expected then
    raise exception 'Una o más ventas ya fueron liquidadas o no pertenecen a este consignador. Actualiza la pantalla.';
  end if;
  if v_total <= 0 then raise exception 'El total a liquidar debe ser mayor que cero'; end if;

  v_paid_on := coalesce(p_paid_on,current_date);
  insert into public.consignment_settlements(consignor_name, amount, paid_on, method, notes, registered_by)
  values(trim(p_consignor_name), v_total, v_paid_on, p_method, nullif(trim(p_notes),''), auth.uid())
  returning id into v_id;

  update public.consignment_sales
    set status='Liquidado', settlement_id=v_id, settled_at=now()
    where id = any(p_sale_ids) and status='Pendiente';

  get diagnostics v_count = row_count;
  if v_count <> v_expected then raise exception 'No se pudieron liquidar todas las ventas seleccionadas'; end if;

  insert into public.expenses
    (concept, category, amount, method, spent_on, notes, created_by, consignment_settlement_id)
  values
    ('Liquidación de consignación · ' || trim(p_consignor_name), 'Consignación', v_total,
     case when p_method='Otro' then 'No especificado' else p_method end,
     v_paid_on, nullif(trim(p_notes),''), auth.uid(), v_id);

  return v_id;
end;
$$;
revoke all on function public.register_consignment_settlement(text,bigint[],date,text,text) from public, anon;
grant execute on function public.register_consignment_settlement(text,bigint[],date,text,text) to authenticated;

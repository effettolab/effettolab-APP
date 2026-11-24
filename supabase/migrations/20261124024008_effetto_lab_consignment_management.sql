alter table public.stock
  add column if not exists consignment_terms_type text,
  add column if not exists consignment_terms_value numeric(12,2);

alter table public.stock
  drop constraint if exists stock_consignment_terms_type_check,
  add constraint stock_consignment_terms_type_check
    check (consignment_terms_type is null or consignment_terms_type in ('owner_fixed','owner_percent','store_fixed')),
  drop constraint if exists stock_consignment_terms_value_check,
  add constraint stock_consignment_terms_value_check
    check (consignment_terms_value is null or consignment_terms_value >= 0),
  drop constraint if exists stock_consignment_terms_pair_check,
  add constraint stock_consignment_terms_pair_check
    check ((consignment_terms_type is null and consignment_terms_value is null)
      or (consignment_terms_type is not null and consignment_terms_value is not null)),
  drop constraint if exists stock_consignment_percent_check,
  add constraint stock_consignment_percent_check
    check (consignment_terms_type <> 'owner_percent' or consignment_terms_value between 0 and 100);

create table if not exists public.consignment_settlements (
  id bigint generated always as identity primary key,
  consignor_name text not null check (length(trim(consignor_name)) > 0),
  amount numeric(12,2) not null check (amount > 0),
  paid_on date not null default current_date,
  method text not null check (method in ('Efectivo','Transferencia','Tarjeta','Otro')),
  notes text,
  registered_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now()
);

create table if not exists public.consignment_sales (
  id bigint generated always as identity primary key,
  invoice_item_id bigint not null unique references public.invoice_items(id) on delete restrict,
  invoice_id bigint not null references public.invoices(id) on delete restrict,
  stock_id bigint not null references public.stock(id) on delete restrict,
  consignor_name text not null,
  gross_amount numeric(12,2) not null check (gross_amount > 0),
  owner_amount numeric(12,2) not null check (owner_amount >= 0),
  business_amount numeric(12,2) not null check (business_amount >= 0),
  status text not null default 'Pendiente' check (status in ('Pendiente','Liquidado')),
  settlement_id bigint references public.consignment_settlements(id) on delete restrict,
  sold_at timestamptz not null default now(),
  settled_at timestamptz,
  check (round(owner_amount + business_amount,2) = round(gross_amount,2))
);

create index if not exists consignment_sales_consignor_status_idx
  on public.consignment_sales (consignor_name, status);
create index if not exists consignment_sales_invoice_idx
  on public.consignment_sales (invoice_id);

alter table public.consignment_sales enable row level security;
alter table public.consignment_settlements enable row level security;

drop policy if exists "consignment sales access" on public.consignment_sales;
create policy "consignment sales access" on public.consignment_sales
  for all to authenticated
  using (public.has_perm('portafolio'))
  with check (public.has_perm('portafolio'));

drop policy if exists "consignment settlements access" on public.consignment_settlements;
create policy "consignment settlements access" on public.consignment_settlements
  for all to authenticated
  using (public.has_perm('portafolio'))
  with check (public.has_perm('portafolio'));

grant select, insert, update, delete on public.consignment_sales to authenticated;
grant select, insert, update, delete on public.consignment_settlements to authenticated;
grant usage, select on sequence public.consignment_sales_id_seq to authenticated;
grant usage, select on sequence public.consignment_settlements_id_seq to authenticated;

create or replace function public.sync_consignment_sale_for_item(p_invoice_item_id bigint)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_item public.invoice_items%rowtype;
  v_invoice public.invoices%rowtype;
  v_stock public.stock%rowtype;
  v_gross numeric(12,2);
  v_owner numeric(12,2);
begin
  if auth.uid() is null or not (public.has_perm('facturacion') or public.has_perm('portafolio')) then
    raise exception 'No tienes permiso para registrar una venta en consignación';
  end if;

  select * into v_item from public.invoice_items where id = p_invoice_item_id;
  if not found then return; end if;
  select * into v_invoice from public.invoices where id = v_item.invoice_id;
  if not found or v_invoice.kind <> 'Factura' then return; end if;
  if v_item.kind <> 'Producto' or v_item.stock_id is null then return; end if;

  select * into v_stock from public.stock where id = v_item.stock_id;
  if not found or v_stock.ownership_type <> 'Consignación' then return; end if;

  if v_stock.consignment_terms_type is null or v_stock.consignment_terms_value is null then
    raise exception 'El artículo "%" está en consignación, pero todavía no tiene un acuerdo económico registrado.', v_stock.name;
  end if;

  v_gross := round(v_item.qty * v_item.unit_price, 2);
  if v_gross <= 0 then raise exception 'El importe de la venta en consignación debe ser mayor que cero'; end if;

  if v_stock.consignment_terms_type = 'owner_fixed' then
    v_owner := round(v_stock.consignment_terms_value * v_item.qty, 2);
  elsif v_stock.consignment_terms_type = 'owner_percent' then
    v_owner := round(v_gross * v_stock.consignment_terms_value / 100, 2);
  elsif v_stock.consignment_terms_type = 'store_fixed' then
    v_owner := round(v_gross - (v_stock.consignment_terms_value * v_item.qty), 2);
  else
    raise exception 'El acuerdo económico del artículo "%" no es válido.', v_stock.name;
  end if;

  if v_owner < 0 or v_owner > v_gross then
    raise exception 'El acuerdo de consignación de "%" produce una distribución fuera del importe de venta.', v_stock.name;
  end if;

  insert into public.consignment_sales
    (invoice_item_id, invoice_id, stock_id, consignor_name, gross_amount, owner_amount, business_amount)
  values
    (v_item.id, v_item.invoice_id, v_stock.id, trim(v_stock.consignor_name),
     v_gross, v_owner, round(v_gross - v_owner, 2))
  on conflict (invoice_item_id) do nothing;
end;
$$;

revoke all on function public.sync_consignment_sale_for_item(bigint) from public, anon, authenticated;

create or replace function public.trg_sync_consignment_sale_item()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.sync_consignment_sale_for_item(new.id);
  return new;
end;
$$;

revoke all on function public.trg_sync_consignment_sale_item() from public, anon, authenticated;

drop trigger if exists sync_consignment_sale_after_item on public.invoice_items;
create trigger sync_consignment_sale_after_item
after insert on public.invoice_items
for each row execute function public.trg_sync_consignment_sale_item();

create or replace function public.trg_sync_consignment_sale_invoice()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare r record;
begin
  if old.kind = 'Cotización' and new.kind = 'Factura' then
    for r in select id from public.invoice_items where invoice_id = new.id loop
      perform public.sync_consignment_sale_for_item(r.id);
    end loop;
  end if;
  return new;
end;
$$;

revoke all on function public.trg_sync_consignment_sale_invoice() from public, anon, authenticated;

drop trigger if exists sync_consignment_sale_after_invoice on public.invoices;
create trigger sync_consignment_sale_after_invoice
after update of kind on public.invoices
for each row execute function public.trg_sync_consignment_sale_invoice();

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
begin
  if auth.uid() is null or not public.has_perm('portafolio') then
    raise exception 'No tienes permiso para registrar liquidaciones de consignación';
  end if;
  if nullif(trim(p_consignor_name),'') is null then raise exception 'Falta el nombre del consignador'; end if;
  if coalesce(array_length(p_sale_ids,1),0) = 0 then raise exception 'Selecciona al menos una venta pendiente'; end if;
  if p_method not in ('Efectivo','Transferencia','Tarjeta','Otro') then raise exception 'Método de pago inválido'; end if;

  select count(*), coalesce(sum(owner_amount),0)
    into v_count, v_total
  from public.consignment_sales
  where id = any(p_sale_ids)
    and status = 'Pendiente'
    and lower(trim(consignor_name)) = lower(trim(p_consignor_name))
  for update;

  v_expected := cardinality(p_sale_ids);
  if v_count <> v_expected then
    raise exception 'Una o más ventas ya fueron liquidadas o no pertenecen a este consignador. Actualiza la pantalla.';
  end if;
  if v_total <= 0 then raise exception 'El total a liquidar debe ser mayor que cero'; end if;

  insert into public.consignment_settlements(consignor_name, amount, paid_on, method, notes, registered_by)
  values(trim(p_consignor_name), v_total, coalesce(p_paid_on,current_date), p_method, nullif(trim(p_notes),''), auth.uid())
  returning id into v_id;

  update public.consignment_sales
    set status='Liquidado', settlement_id=v_id, settled_at=now()
    where id = any(p_sale_ids) and status='Pendiente';

  get diagnostics v_count = row_count;
  if v_count <> v_expected then raise exception 'No se pudieron liquidar todas las ventas seleccionadas'; end if;
  return v_id;
end;
$$;

revoke all on function public.register_consignment_settlement(text,bigint[],date,text,text) from public, anon;
grant execute on function public.register_consignment_settlement(text,bigint[],date,text,text) to authenticated;

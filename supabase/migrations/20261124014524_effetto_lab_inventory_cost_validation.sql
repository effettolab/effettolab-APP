-- EFFETTO LAB: validación de propiedad y costos de inventario.
-- Un costo desconocido nunca debe convertirse automáticamente en costo cero.
-- Los artículos en consignación no llevan costo propio de EFFETTO LAB.

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname='stock_service_must_be_owned'
      and conrelid='public.stock'::regclass
  ) then
    alter table public.stock
      add constraint stock_service_must_be_owned
      check (item_type <> 'Servicio' or ownership_type='Propio');
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname='stock_consignor_required'
      and conrelid='public.stock'::regclass
  ) then
    alter table public.stock
      add constraint stock_consignor_required
      check (
        ownership_type <> 'Consignación'
        or nullif(btrim(consignor_name),'') is not null
      );
  end if;
end $$;

create or replace function public.clear_stock_cost_for_nonowned_items()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if NEW.item_type <> 'Producto' or NEW.ownership_type='Consignación' then
    delete from public.stock_costs where stock_id=NEW.id;
  end if;
  return NEW;
end;
$$;
revoke all on function public.clear_stock_cost_for_nonowned_items() from public, anon, authenticated;
drop trigger if exists trg_clear_stock_cost_for_nonowned_items on public.stock;
create trigger trg_clear_stock_cost_for_nonowned_items
after insert or update of item_type,ownership_type on public.stock
for each row execute function public.clear_stock_cost_for_nonowned_items();

create or replace function public.capture_order_item_cost_snapshot()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare v_cost numeric(12,2);
begin
  if NEW.kind='Producto' and NEW.stock_id is not null then
    select sc.cost into v_cost
    from public.stock s
    join public.stock_costs sc on sc.stock_id=s.id
    where s.id=NEW.stock_id
      and coalesce(s.ownership_type,'Propio')='Propio'
      and s.item_type='Producto';
    if v_cost is not null and v_cost>0 then
      insert into public.cost_snapshots(source_type,source_item_id,stock_id,unit_cost)
      values('order_item',NEW.id,NEW.stock_id,round(v_cost,2))
      on conflict (source_type,source_item_id) do nothing;
    end if;
  end if;
  return NEW;
end;
$$;
revoke all on function public.capture_order_item_cost_snapshot() from public, anon, authenticated;

create or replace function public.capture_invoice_item_cost_snapshot()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_invoice_kind text;
  v_cost numeric(12,2);
begin
  select i.kind into v_invoice_kind
  from public.invoices i where i.id=NEW.invoice_id;
  if v_invoice_kind='Factura' and NEW.kind='Producto' and NEW.stock_id is not null then
    if NEW.order_item_id is not null then
      select cs.unit_cost into v_cost
      from public.cost_snapshots cs
      where cs.source_type='order_item' and cs.source_item_id=NEW.order_item_id;
    end if;
    if v_cost is null then
      select sc.cost into v_cost
      from public.stock s
      join public.stock_costs sc on sc.stock_id=s.id
      where s.id=NEW.stock_id
        and coalesce(s.ownership_type,'Propio')='Propio'
        and s.item_type='Producto';
    end if;
    if v_cost is not null and v_cost>0 then
      insert into public.cost_snapshots(source_type,source_item_id,stock_id,unit_cost)
      values('invoice_item',NEW.id,NEW.stock_id,round(v_cost,2))
      on conflict (source_type,source_item_id) do nothing;
    end if;
  end if;
  return NEW;
end;
$$;
revoke all on function public.capture_invoice_item_cost_snapshot() from public, anon, authenticated;

create or replace function public.capture_quote_costs_when_invoiced()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare r record; v_cost numeric(12,2);
begin
  if OLD.kind='Cotización' and NEW.kind='Factura' then
    for r in
      select ii.id,ii.stock_id,ii.kind,ii.order_item_id,
             coalesce(s.ownership_type,'Propio') as ownership_type,
             coalesce(s.item_type,'Producto') as item_type
      from public.invoice_items ii
      left join public.stock s on s.id=ii.stock_id
      where ii.invoice_id=NEW.id and ii.kind='Producto' and ii.stock_id is not null
    loop
      v_cost := null;
      if r.order_item_id is not null then
        select cs.unit_cost into v_cost
        from public.cost_snapshots cs
        where cs.source_type='order_item' and cs.source_item_id=r.order_item_id;
      end if;
      if v_cost is null and r.ownership_type='Propio' and r.item_type='Producto' then
        select sc.cost into v_cost from public.stock_costs sc where sc.stock_id=r.stock_id;
      end if;
      if v_cost is not null and v_cost>0 then
        insert into public.cost_snapshots(source_type,source_item_id,stock_id,unit_cost)
        values('invoice_item',r.id,r.stock_id,round(v_cost,2))
        on conflict (source_type,source_item_id) do nothing;
      end if;
    end loop;
  end if;
  return NEW;
end;
$$;
revoke all on function public.capture_quote_costs_when_invoiced() from public, anon, authenticated;

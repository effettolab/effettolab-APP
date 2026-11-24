-- EFFETTO LAB: comisiones comerciales exclusivamente sobre mercancía.
-- Las reparaciones y demás conceptos de servicio se liquidan por su propio flujo técnico.

create or replace function public.sync_sales_commission(p_invoice_id bigint)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_kind text;
  v_seller uuid;
  v_product_total numeric(12,2);
begin
  select i.kind,i.salesperson_id into v_kind,v_seller
  from public.invoices i where i.id=p_invoice_id;
  if not found then return; end if;

  if v_kind='Factura' and v_seller is not null then
    select coalesce(sum(ii.qty*ii.unit_price),0)::numeric(12,2)
    into v_product_total
    from public.invoice_items ii
    where ii.invoice_id=p_invoice_id
      and ii.kind='Producto';

    if v_product_total>0 then
      insert into public.sales_commissions(invoice_id,salesperson_id,sale_amount,status)
      values(p_invoice_id,v_seller,v_product_total,'Por definir')
      on conflict (invoice_id) do update
        set salesperson_id=excluded.salesperson_id,
            sale_amount=excluded.sale_amount,
            status=case
              when public.sales_commissions.status='Anulada' then 'Por definir'
              else public.sales_commissions.status
            end,
            updated_at=now();
    else
      update public.sales_commissions
      set status=case when status='Pagada' then status else 'Anulada' end,
          updated_at=now()
      where invoice_id=p_invoice_id;
    end if;
  else
    update public.sales_commissions
    set status=case when status='Pagada' then status else 'Anulada' end,
        updated_at=now()
    where invoice_id=p_invoice_id;
  end if;
end;
$$;
revoke all on function public.sync_sales_commission(bigint) from public, anon, authenticated;

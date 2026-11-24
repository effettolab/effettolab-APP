create or replace function public.set_invoice_salesperson(
  p_invoice_id bigint,
  p_salesperson_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_current uuid;
begin
  if auth.uid() is null or not public.has_perm('facturacion') then
    raise exception 'No tienes permiso para atribuir ventas.';
  end if;

  if p_salesperson_id is not null and p_salesperson_id not in (
    '1cf30c52-5f3f-4957-a303-a8dc1a83c5d3'::uuid,
    '98dc67ce-7bae-4735-a74f-03734c212759'::uuid
  ) then
    raise exception 'El vendedor debe ser Jason o Nando.';
  end if;

  select i.salesperson_id into v_current
  from public.invoices i where i.id=p_invoice_id for update;
  if not found then raise exception 'El documento no existe.'; end if;

  if v_current is not null
     and v_current is distinct from auth.uid()
     and not public.has_perm('$') then
    raise exception 'Solo puedes modificar la atribución de tu propia venta.';
  end if;
  if p_salesperson_id is distinct from auth.uid()
     and not public.has_perm('$') then
    raise exception 'Solo puedes asignar ventas a tu propia cuenta.';
  end if;

  update public.invoices
  set salesperson_id=p_salesperson_id,updated_at=now()
  where id=p_invoice_id;
end;
$$;
revoke all on function public.set_invoice_salesperson(bigint,uuid) from public, anon;
grant execute on function public.set_invoice_salesperson(bigint,uuid) to authenticated;

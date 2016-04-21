set linesize 80;
begin
  lws_vbbi.build_vbbi_file;
  lws_vbbi.build_delete_invoices;
end;
/
select line from vger_support.vbbi_pac_invoice_data
where delivered = 'N'
order by invoice_id, seq;

update vger_support.vbbi_pac_invoice_data
set delivered = 'Y'
where delivered = 'N';

update vger_support.vbbi_delete_invoices
set delivered = 'Y'
where delivered = 'N';

commit;

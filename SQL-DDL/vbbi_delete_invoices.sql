/*  Some invoices get partially processed in PAC, then rejected.
    These require a Z20 DELETE transaction be sent.
    This table keeps track of those transactions, pending and completed.
*/
drop table vger_support.vbbi_delete_invoices purge;
create table vger_support.vbbi_delete_invoices (
  invoice_id int not null
, invoice_number varchar2(25) not null -- for convenience with Acq/LBS/PAC data
, extract_date date default sysdate not null
, delivered char(1) default 'N' constraint ck_del_inv_delivered_yn check (delivered in ('N', 'Y'))
, constraint pk_vbbi_delete_invoices primary key (invoice_id, extract_date)
);

-- template
insert into vger_support.vbbi_delete_invoices (invoice_id, invoice_number) values ();

--20090812
insert into vger_support.vbbi_delete_invoices (invoice_id, invoice_number)
  select invoice_id, invoice_number from ucladb.invoice 
  where invoice_number in ('818357787', '818540903', 'UCLA2009-12');

commit;

select * from vger_support.vbbi_delete_invoices;

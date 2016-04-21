drop table vger_support.vbbi_batch_errors purge;
create table vger_support.vbbi_batch_errors (
  client_id varchar2(4)
, vck varchar2(30)
, invoice_number varchar2(30)
, txn_id char(3)
, sub_txn_id char(3)
, inv_line_number int
, error_code int
, error_description varchar2(20)
, z20d_required char(1)
, error_date date default trunc(sysdate) not null
)
;
create index vger_support.ix_vbbi_batch_errors_invnum on vger_support.vbbi_batch_errors (invoice_number);
grant select on vger_support.vbbi_batch_errors to public;

select * from vger_support.vbbi_batch_errors vbe where z20d_required = 'Y';
where not exists (select * from ucladb.invoice where invoice_number = vbe.invoice_number);


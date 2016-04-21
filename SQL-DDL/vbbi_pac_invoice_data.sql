drop table vger_support.vbbi_pac_invoice_data purge;
create table vger_support.vbbi_pac_invoice_data (
  invoice_id int not null
, seq int not null
, line char(80) not null
, extract_date date default sysdate not null
, delivered char(1) default 'N' constraint ck_delivered_yn check (delivered in ('N', 'Y'))
, constraint pk_vbbi_pac_invoice_data primary key (invoice_id, seq)
)
;

grant select on vger_support.vbbi_pac_invoice_data to public;

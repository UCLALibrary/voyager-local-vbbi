-- Log data from lws_vbbi process
drop table vger_support.vbbi_log_data purge;
create table vger_support.vbbi_log_data (
  invoice_id int not null
, message varchar2(100) not null
, amount number not null
, constraint pk_vbbi_log_data primary key (invoice_id, message)
);

grant select on vger_support.vbbi_log_data to public;

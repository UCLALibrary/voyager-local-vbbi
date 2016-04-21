create or replace view vger_support.vbbi_voy_invoice_data as
with invoices as (
  select 
    i.invoice_id
  , i.invoice_number
  , i.invoice_date
  , i.currency_code
  , i.conversion_rate
  , ucladb.tobasecurrency(i.total, currency_code, conversion_rate) as voy_invoice_total
  , v.vendor_code
  , v.institution_id as vck
  from ucladb.invoice i
  inner join ucladb.invoice_status ist on i.invoice_status = ist.invoice_status
  inner join ucladb.vendor v on i.vendor_id = v.vendor_id
  where (
    ist.invoice_status_desc = 'Approved'
    and i.invoice_status_date >= to_date('20090713', 'YYYYMMDD')
    and i.invoice_number not like 'HOLD%' -- LBS "Hold for pick-up" invoices
    and i.invoice_number not like 'RECHARGE%' -- regular recharges
    and i.invoice_number not like 'UCLARCHG%' -- CDL recharges
    and i.invoice_number not like 'WIRE%' -- LBS "wire transfer" invoices
    and i.invoice_number not like 'PACKAGE%' -- package subscriptions invoice, when the taxable amount is not identified 
    and i.invoice_number not like 'REIMBURSE%' -- reimbursements, which LBS handles differently
    and i.invoice_number not like 'REFUND%' -- refunds, which LBS handles differently
    and i.invoice_number not like 'RUSH%' -- rush requests, which LBS handles differently
    and i.invoice_number not like 'FOREIGN%' -- direct foreign currency payments, which LBS handles differently
    and i.invoice_number not like 'ADJUST%' -- per LBS request 20110705
    and i.invoice_number not like 'SPECIAL%' -- per LBS request 20120709
    and regexp_instr(i.invoice_number, '^5[0-9]{3}[A-Z]{3}[0-9]') = 0 -- ProCard invoices
    and v.vendor_code != 'LBS'
    -- 20090720: disabled VCK regex check, need to research valid forms of VCK, some have ending letter
    --and regexp_instr(v.institution_id, '^[0-9]{9}$') = 1
    and v.institution_id is not null
  )
  -- occasionally pre-2009/2010 invoices need to be extracted - uncomment and edit the below as needed
  --or invoice_id in (70057)
)
select
  substr(trim(invoice_number), 1, 21) as invoice_number -- PAC only supports 21 characters (plus 2 reserved for PAC, which we shouldn't use)
, invoice_number as full_invoice_number -- for debugging
, invoice_id
, invoice_date
, voy_invoice_total
, vck
, po_number
, po_reference
, inv_line_item_id
, substr(description, 1, 55) as description -- PAC z21 format only supports 55 chars
, is_line_item
, lib_tax_code
, fau_location
, fau_account
, fau_cost_center
, fau_fund
, fau_sub
, fau_object
, fau_project
, fau_source
, sum(percentage) as percentage
, sum(usd_amount) as amount
from (
  -- Data from invoice lines
  select 
    i.invoice_number
  , i.invoice_id
  , i.invoice_date
  , i.voy_invoice_total
  , i.vendor_code
  , i.vck
  , ili.inv_line_item_id
  , po.po_number
  , lws_utility.pac_number_format(po.po_id, 10, 0) as po_reference
  , bt.bib_id
  -- Voyager 9.1.1: CRLF started appearing in piece_identifier sometimes; strip it out here
  , bt.bib_id || ': ' || replace(ili.piece_identifier, chr(13) || chr(10), '') as description
  , f.institution_fund_id as fau
  , f.fund_code
  , f.fund_name
  , cfc.fau_location
  , cfc.fau_account
  , cfc.fau_cost_center
  , cfc.fau_fund
  , cfc.fau_sub
  , cfc.fau_object
  , cfc.fau_project
  --, cfc.fau_source
  , to_char(i.invoice_id) as fau_source --workaround to get our unique invoice id into PAC for linking back to Voyager
  , 'Y' as is_line_item
  -- VBT-441: Voyager 9.1+ ilif percentage is 1..100000000 (10^8) for super-precision; VBBI still expects 1..100, so divide by 10^6
  , case when (ilif.percentage / 1000000) != 100 then 'Y' else 'N' end as split_payment
  , (ilif.percentage / 1000000) as percentage
  --, substr(ili.piece_identifier, 1, 2) as old_lib_tax_code
  , case
      when upper(substr(ili.piece_identifier, 1, 2)) in ('EX', 'TM', 'TS', 'VR') then upper(substr(ili.piece_identifier, 1, 2))
      else decode(vger_support.has_vr_tax(i.invoice_id), 'T', 'VR', 'F', 'TM')
    end as lib_tax_code
  ,	ucladb.toBaseCurrency(ilif.amount, i.currency_code, i.conversion_rate) AS usd_amount
  , ilif.amount as raw_amount
  from invoices i
  inner join ucladb.invoice_line_item ili on i.invoice_id = ili.invoice_id
  inner join ucladb.invoice_line_item_funds ilif on ili.inv_line_item_id = ilif.inv_line_item_id
  inner join ucladb.line_item_copy_history lich 
    on ili.inv_line_item_id = lich.inv_line_item_id
    and ilif.copy_id = lich.copy_id
    and lich.line_item_status = 6 -- Invoiced
  inner join ucladb.line_item li on ili.line_item_id = li.line_item_id
  inner join ucladb.purchase_order po on li.po_id = po.po_id
  inner join ucladb.fund f on ilif.ledger_id = f.ledger_id and ilif.fund_id = f.fund_id
  inner join vger_support.campus_fau_components cfc on f.ledger_id = cfc.ledger_id and f.fund_id = cfc.fund_id
  inner join ucladb.bib_text bt on li.bib_id = bt.bib_id
  union all
  -- Data from invoice adjustments
  select
    i.invoice_number
  , i.invoice_id
  , i.invoice_date
  , i.voy_invoice_total
  , i.vendor_code
  , i.vck
  , null as inv_line_item_id
  , null as po_number
  , lws_utility.get_blanks(10) as po_reference
  , null as bib_id
  , ar.reason_text as description
  , f.institution_fund_id as fau
  , f.fund_code
  , f.fund_name
  , cfc.fau_location
  , cfc.fau_account
  , cfc.fau_cost_center
  , cfc.fau_fund
  , cfc.fau_sub
  , cfc.fau_object
  , cfc.fau_project
  --, cfc.fau_source
  , to_char(i.invoice_id) as fau_source --workaround to get our unique invoice id into PAC for linking back to Voyager
  , 'N' as is_line_item
  , case when fp.percentage != 100 then 'Y' else 'N' end as split_payment
  , fp.percentage
  , substr(ar.reason_text, 1, 2) as lib_tax_code
  ,	ucladb.toBaseCurrency(fp.amount, i.currency_code, i.conversion_rate) AS usd_amount
  , fp.amount as raw_amount
  from invoices i
  inner join ucladb.price_adjustment pa on i.invoice_id = pa.object_id and pa.object_type = 'C'
  inner join ucladb.adjust_reason ar on pa.reason_id = ar.reason_id
  inner join ucladb.fund_payment fp on pa.payment_id = fp.payment_id
  inner join ucladb.fund f on fp.ledger_id = f.ledger_id and fp.fund_id = f.fund_id
  inner join vger_support.campus_fau_components cfc on f.ledger_id = cfc.ledger_id and f.fund_id = cfc.fund_id
)
group by
  invoice_number
, invoice_id
, invoice_date
, voy_invoice_total
, vck
, po_number
, po_reference
, inv_line_item_id
, description
, fau_location
, fau_account
, fau_cost_center
, fau_fund
, fau_sub
, fau_object
, fau_project
, fau_source
, is_line_item
, lib_tax_code
having sum(usd_amount) != 0
;

grant select on vger_support.vbbi_voy_invoice_data to public with grant option;

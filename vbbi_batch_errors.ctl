LOAD DATA
APPEND
INTO TABLE vger_support.vbbi_batch_errors
FIELDS TERMINATED BY x'09'
TRAILING NULLCOLS
( client_id
, vck "TRIM(:vck)"
, invoice_number "TRIM(:invoice_number)"
, txn_id
, sub_txn_id
, inv_line_number
, error_code
, error_description
, z20d_required
)

with tmp_aum as (
  select cardid, sum(aum) as sum_aum
  from mis.fact_portfolio
  where latest_in_month_flag =1
  and  product_lv1 ='tfex' 
  and year_month='2026-02'
  group by cardid
),

daily_aum_by_cust as (
select cardid, record_date, sum(aum) as sum_daily_aum 
from mis.fact_portfolio
where record_date >= '2025-03-01'
and product_lv1 ='tfex' 
group by record_date, cardid
),

max_daily_aum as (
select cardid, max(sum_daily_aum) as max_daily_aum
from daily_aum_by_cust
group by cardid
),

credit as (  --latest creditlimit
  select client_code, client_account, approval_credit_limit
 from scbs_etl.scbs_center_tfex_client_account
  where dt = (select max(dt) from scbs_etl.scbs_center_tfex_client_account)
),

margin as (  --latest margin
  select client_account_code, initial_margin 
  from scbs_etl.scbs_center_tfex_r2620
  where dt = (select max(dt) from scbs_etl.scbs_center_tfex_r2620)
),

max_margin as ( --max margin since last year
  select client_account_code, max(initial_margin) as max_initial_margin_last_year
  from scbs_etl.scbs_center_tfex_r2620
  where data_date >= '2025-03-01'
  group by client_account_code
),

eq_bal as (
  select client_account_code, equity_balance 
  from scbs_etl.scbs_center_tfex_r2620
  where dt = (select max(dt) from scbs_etl.scbs_center_tfex_r2620)
),

max_eq_bal as (
  select client_account_code, max(equity_balance) as max_equity_balance_last_year
  from scbs_etl.scbs_center_tfex_r2620
  where data_date >= '2025-03-01'
  group by client_account_code
),

max_init_margin_per_creditline as (
  select client_account_code, max(initial_margin/approval_credit_limit) as max_initialmargin_per_creditline
  from scbs_etl.scbs_center_tfex_r2620 a
  left join scbs_etl.scbs_center_tfex_client_account b
  on a.client_account_code = b.client_account
  and a.dt = b.dt
  where a.dt >= '20250301'
  group by client_account_code
),

result as (
select distinct a.src_dt, a.src_account, a.cardid, a.close_date, nvl(c.cust_name_th,cis.short_name_th) as cust_name_th, a.marketing_team, a.marketing_name_th, c.cust_type
, case
      when upper(e.reasoncode) = 'LOMB' then 'Y'
      else 'N'
  end as flag_lombard_loan
, case
      when upper(e.reasoncode) = 'PPBL' then 'Y'
      else 'N'
  end as PPBL
, a.open_date, c.latest_trade_date
, credit.approval_credit_limit as credit_line
, margin.initial_margin as initial_margin
, max_margin.max_initial_margin_last_year as max_initial_margin_last_year
, eq_bal.equity_balance as equity_balance
, max_eq_bal.max_equity_balance_last_year as max_equity_balance_last_year
, max_ini_margin_credit.max_initialmargin_per_creditline as max_innitial_margin_creditline
 from mis.dim_account a
 left join mis.dim_customer c
 on a.cardid = c.cardid

left join 
(select c2.card_number, c2.customer_id, c1.short_name_th
 from (SELECT * FROM per_std_vr.cis_customer_profile where dt= (select max(dt) from per_std_vr.cis_customer_profile)) c1 
left join (select * from per_std_vr.cis_customer_card_data where dt= (select max(dt) from per_std_vr.cis_customer_card_data)) c2
on c1.customer_id=c2.customer_id) cis
on a.cardid = cis.card_number

 left join tmp_aum b
 on a.cardid = b.cardid
 left join max_daily_aum d
 on a.cardid = d.cardid
 left join scbs_etl.cdb_eq_transaction_lock_profile e
 on a.custcode = e.custcode
 left join credit
 on a.account = credit.client_account
 left join margin
 on a.account = margin.client_account_code
 left join max_margin
 on a.account = max_margin.client_account_code
 left join eq_bal
 on a.account = eq_bal.client_account_code
 left join max_eq_bal
 on a.account = max_eq_bal.client_account_code
 left join max_init_margin_per_creditline max_ini_margin_credit
 on a.account = max_ini_margin_credit.client_account_code

 where a.is_tfex =1 and a.close_date = '9999-12-31')

select * from result
with tmp_aum as (
  select cardid, sum(aum) as sum_aum
  from mis.fact_portfolio
  where latest_in_month_flag =1
  and  product_lv1 ='offshore' 
  and year_month='2026-02'
  group by cardid
),

daily_aum_by_cust as (
select cardid, record_date, sum(aum) as sum_daily_aum 
from mis.fact_portfolio
where record_date between '2025-03-01' and '2026-02-28'
and product_lv1 ='offshore'
group by record_date, cardid
),

max_daily_aum as (
select cardid, max(sum_daily_aum) as max_daily_aum
from daily_aum_by_cust
group by cardid
),

credit as (
SELECT
    custcode,
    account,
    effdate,
    appcreditline
FROM (  
    SELECT
        custcode,
        account,
        effdate,
        enddate,
        appcreditline,
        ROW_NUMBER() OVER (
            PARTITION BY custcode, account
            ORDER BY effdate DESC, enddate DESC
        ) AS rn
    FROM scbs_etl.scbs_center_eq_journal_credit_approval
    WHERE dt = (SELECT MAX(dt) FROM scbs_etl.scbs_center_eq_journal_credit_approval)) t
WHERE rn = 1    
),

os_transaction as (
  select record_date, cardid, src_dt, src_account, account, sum(trading_value) as daily_amount
 from mis.fact_transactions
 where lower(product_lv1)='offshore'
 and src_dt between '20250301' and '20260228'
 and txn_type = 'Buy'
 group by record_date, cardid, src_dt, src_account, account
),

max_txn_per_credit as (
  select t.src_account, t.account, max(t.daily_amount/c.appcreditline) as max_txn_credit
 from os_transaction t
 left join 
 (select dt, custcode,account,effdate, appcreditline 
 from scbs_etl.scbs_center_eq_journal_credit_approval
  where dt||custcode||account||effdate in (
  select dt||custcode||account||max(effdate) 
 from scbs_etl.scbs_center_eq_journal_credit_approval
  group by dt,custcode,account)) c
 on t.account = c.account and t.src_dt = c.dt
 where c.dt between '20250301' and '20260228'
 group by t.src_account, t.account
),


result as (
select distinct a.src_dt, a.src_account, a.cardid, c.cust_name_th, a.marketing_team, a.marketing_name_th, c.cust_type
, case
      when lomb.custcode is not null then 'Y'
      else 'N'
  end as flag_lombard_loan
, case
      when ppb.custcode is not null then 'Y'
      else 'N'
  end as PPBL
, a.open_date
, c.latest_trade_date
, credit.effdate as last_date_change_creditline
, credit.appcreditline as credit_line
, b.sum_aum as current_asset
, d.max_daily_aum as max_asset_1Year
, nvl(os_txn.max_txn_credit,0) as max_tradingamount_per_creditline

 from mis.dim_account a
 left join mis.dim_customer c
 on a.cardid = c.cardid
 left join tmp_aum b
 on a.cardid = b.cardid
 left join max_daily_aum d
 on a.cardid = d.cardid
 left join (select custcode from scbs_etl.cdb_eq_transaction_lock_profile where reasoncode='LOMB') lomb
 on a.custcode = lomb.custcode
 left join (select custcode from scbs_etl.cdb_eq_transaction_lock_profile where reasoncode='PPBL') ppb
 on a.custcode = ppb.custcode
 left join credit
 on a.src_account = credit.account
 left join max_txn_per_credit os_txn
 on a.account = os_txn.account
 where a.is_offshore =1 and a.close_date = '9999-12-31')

select * from result
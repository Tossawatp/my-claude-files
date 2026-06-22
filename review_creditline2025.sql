set isolation to dirty read;

drop table if exists tmp_customer;
drop table if exists tmp_customer2;
drop table if exists tmp_customer3;
drop table if exists tmp_customer4;
drop table if exists tmp_customer5;
drop table if exists tmp_LOMB;
drop table if exists tmp_PPBL;
drop table if exists tmp_maxjcas1;
drop table if exists tmp_maxjcas;
drop table if exists tmp_jcas;
drop table if exists tmp_maxcreditSN;
drop table if exists tmp_hc;
drop table if exists tmp_asset;
drop table if exists tmp_maxasset;
drop table if exists tmp_maxutilizeAR;
drop table if exists tmp_maxutilizeDEBT;
drop table if exists tmp_max;
drop table if exists tmp_summax;

select 'Start tmp_customer' st, current from tcc;

select c.account,c.custacct,c.xchgmkt,
       a.cardid,trim(nvl(a.ttitle,''))||' '||trim(nvl(a.tname,''))||' '||trim(nvl(a.tsurname,'')) name,
       e.teamename,d.usertname mktname,
       case
           when a.personcode = '0' or a.personcode = '2' then 'นิติบุคคล'
           when a.personcode = '1' or a.personcode = '3' then 'บุคคลธรรมดา'
       end flag_person,
       case c.custacct
           when '5' then 'Y'
           else 'N'
       end flag_TSFC,
       case
           when f.class2 = '3' and f.remark1 = 'H' then 'Y'
           else 'N'
       end flag_ALGO,
       c.cashcreditflag,
       b.opendate,c.lasttrade
from tct a,tca b,tcas c,tcas2 f,tus d,ttm e
where 1=1
and a.custcode = b.custcode
and b.account = c.account
and c.account = f.account
and c.xchgmkt = f.xchgmkt
and a.mktid = d.userid
and d.teamid = e.teamid
and c.acctstatus = 'N'
into temp tmp_customer with no log;
create index tmp_customer_idx on tmp_customer(account);

select 'Finish tmp_customer' st, current from tcc;

-------------------------------------------------------- EQ --------------------------------------------------------
select a.*,
       'Y' flag_LOMB
from tmp_customer a, tlock b
where 1=1
and a.account = b.account
and a.xchgmkt = '1'
and b.effdate <= today
and b.enddate > today
and b.reasoncode = 'LOMB'
into temp tmp_LOMB with no log;

select a.*,
      'Y' flag_PPBL
from tmp_customer a, tlock b
where 1=1
and a.account = b.account
and a.xchgmkt = '1'
and b.effdate <= today
and b.enddate > today
and b.reasoncode = 'PPBL'
into temp tmp_PPBL with no log;

select 'Start tmp_customer2' st, current from tcc;

select a.*
      ,case when flag_LOMB is null then 'N'
            else flag_LOMB
       end flag_LOMB
      ,case when flag_PPBL is null then 'N'
            else flag_PPBL
       end flag_PPBL
from tmp_customer a,outer tmp_LOMB b, outer tmp_PPBL c
where 1=1
and a.account = b.account
and a.account = c.account
and a.xchgmkt = '1'
into temp tmp_customer2 with no log;
create index tmp_customer2_idx on tmp_customer2(account,xchgmkt);

select 'Finish tmp_customer2' st, current from tcc;

select account,max(effdate) max_effdate
from jcas
where 1=1
and tempcreditlineflag = '0'
and xchgmkt = '1'
group by 1
into temp tmp_maxjcas1 with no log;

select a.account,max_effdate,max(edittime) max_edittime
from tmp_maxjcas1 a,jcas b
where 1=1
and a.account = b.account
and a.max_effdate = b.effdate
and tempcreditlineflag = '0'
and xchgmkt = '1'
group by 1,2
into temp tmp_maxjcas with no log;

select a.*
from jcas a,tmp_maxjcas b
where 1=1
and a.account = b.account
and a.effdate = b.max_effdate
and a.edittime = b.max_edittime
and tempcreditlineflag = '0'
and xchgmkt = '1'
into temp tmp_jcas with no log;

select 'Start tmp_customer3' st, current from tcc;

select a.*,
       b.effdate line_effective,b.appcreditline
from tmp_customer2 a,outer tmp_jcas b
where a.account = b.account
and a.xchgmkt = b.xchgmkt
into temp tmp_customer3 with no log;
create index tmp_customer3_idx on tmp_customer3(account);

select 'Finish tmp_customer3' st, current from tcc;

select 'Start Update tmp_customer3' st, current from tcc;

update tmp_customer3 set appcreditline = (select appcreditline from tcas where 1=1 and xchgmkt = '1' and tmp_customer3.account = tcas.account)
where 1=1
and appcreditline is null
and account in (select account from tcas where 1=1 and xchgmkt = '1')
;
update tmp_customer3 set line_effective = (select lineeffective from tcas where 1=1 and xchgmkt = '1' and tmp_customer3.account = tcas.account)
where 1=1
and line_effective is null
and account in (select account from tcas where 1=1 and xchgmkt = '1')
;

select 'Finish Update tmp_customer3' st, current from tcc;

select a.account,max(a.effdate) max_effdate
from jcas a,sncas b
where 1=1
and a.account = b.account
and a.effdate between b.effdate and b.issuedate
and tempcreditlineflag = '1'
and appcreditline < originalcreditline
and b.delflag = '0'
group by 1
into temp tmp_maxcreditSN with no log;

select 'Start tmp_customer4' st, current from tcc;

select a.*,
       b.max_effdate tempcreditline_date
from tmp_customer3 a,outer tmp_maxcreditSN b
where 1=1
and a.account = b.account
into temp tmp_customer4 with no log;
create index tmp_customer4_idx on tmp_customer4(account);

select 'Finish tmp_customer4' st, current from tcc;

select a.postdate,a.account,
       case when b.mktval is null then a.mktval
            else b.mktval 
       end mktval_hc,a.cashbalance,a.debt
from tmg a,outer tmha b
where 1=1
and a.postdate = b.postdate
and a.account = b.account
and a.xchgmkt = '1'
and a.postdate = kd_bankdate(today,-1)
into temp tmp_hc with no log;

select 'Start tmp_customer5' st, current from tcc;

select a.*,(b.mktval_hc+b.cashbalance) asset,b.debt
from tmp_customer4 a,outer tmp_hc b
where 1=1
and a.account = b.account
into temp tmp_customer5 with no log;
create index temp_customer5_idx on tmp_customer5(account);

select 'Finish tmp_customer5' st, current from tcc;

select 'Start tmp_asset' st, current from tcc;

select a.account,(a.mktval+b.cashbalance) asset
from tmha a,tmg b
where 1=1
and a.postdate = b.postdate
and a.account = b.account
and a.xchgmkt = b.xchgmkt
and b.xchgmkt = '1'
into temp tmp_asset with no log;

select 'Finish tmp_asset' st, current from tcc;

select 'Start tmp_maxasset' st, current from tcc;

select account,max(asset) max_asset
from tmp_asset
group by 1
into temp tmp_maxasset with no log;

select 'Finish tmp_maxasset' st, current from tcc;

select 'Start tmp_maxutilizeAR' st, current from tcc;

select account,max(ar_trade/comp_creditline) max_utilizeAR 
from tmg
where 1=1
and xchgmkt = '1'
and ar_trade > 0
and comp_creditline > 0
group by 1
into temp tmp_maxutilizeAR with no log;

select 'Finish tmp_maxutilizeAR' st, current from tcc;

select 'Start tmp_maxutilizeDEBT' st, current from tcc;

select account,max(debt/comp_creditline) max_utilizedebt
from tmg
where 1=1
and xchgmkt = '1'
and debt > 0
and comp_creditline > 0
group by 1
into temp tmp_maxutilizeDEBT with no log;

select 'Finish tmp_maxutilizeDEBT' st, current from tcc;

select 'Start tmp_max' st, current from tcc;

select account
         ,case when max_asset is null then cast(0.00 as decimal(20,2))
             else max_asset 
        end max_asset
       ,cast(0.00 as decimal(20,2)) max_utilizeAR
       ,cast(0.00 as decimal(20,2)) max_utilizedebt
from tmp_maxasset 
where 1=1
union all
select account
         ,cast(0.00 as decimal(20,2)) max_asset
         ,case when max_utilizeAR is null then cast(0 as decimal(20,2))
            else max_utilizeAR
          end max_utilizeAR
         ,cast(0.00 as decimal(20,2)) max_utilizedebt
from tmp_maxutilizeAR
where 1=1
union all
select account
         ,cast(0.00 as decimal(20,2)) max_asset
         ,cast(0.00 as decimal(20,2)) max_utilizeAR
         ,case when max_utilizedebt is null then cast(0 as decimal(20,2))
                  else max_utilizedebt
          end max_utilizedebt
from tmp_maxutilizeDEBT
where 1=1
into temp tmp_max with no log;

select account
      ,cast(sum(max_asset) as decimal(20,6)) max_asset
      ,cast(sum(max_utilizeAR) as decimal(20,6)) max_utilizeAR
      ,cast(sum(max_utilizedebt) as decimal(20,6)) max_utilizedebt
from tmp_max
group by 1
into temp tmp_summax with no log;

select 'Finish tmp_max' st, current from tcc;

--unload to /NASBackup2/reviewcredit/reviewcredit2025_EQ.txt
select kd_bankdate(today,-1) asofdate
      ,a.*
      ,case when max_asset is null then 0
               else max_asset
       end max_asset
      ,case when max_utilizeAR is null then 0
              else max_utilizeAR
       end max_utilizeAR
      ,case when max_utilizedebt is null then 0
              else max_utilizedebt
       end max_utilizedebt
from tmp_customer5 a, outer tmp_summax b
where 1=1
and a.account = b.account
;
-------------------------------------------------------- EQ --------------------------------------------------------


-------------------------------------------------------- BOND --------------------------------------------------------
drop table if exists tmp_customer2;
drop table if exists tmp_customer3;
drop table if exists tmp_customer4;
drop table if exists tmp_customer5;
drop table if exists tmp_LOMB;
drop table if exists tmp_PPBL;
drop table if exists tmp_maxjcas1;
drop table if exists tmp_maxjcas;
drop table if exists tmp_jcas;
drop table if exists tmp_maxcreditSN;
drop table if exists tmp_hc;
drop table if exists tmp_asset;
drop table if exists tmp_maxasset;
drop table if exists tmp_maxutilizeAR;
drop table if exists tmp_maxutilizeDEBT;
drop table if exists tmp_max;
drop table if exists tmp_summax;

select a.*,
       'Y' flag_LOMB
from tmp_customer a, tlock b
where 1=1
and a.account = b.account
and a.xchgmkt = '3'
and b.effdate <= today
and b.enddate > today
and b.reasoncode = 'LOMB'
into temp tmp_LOMB with no log;

select a.*,
      'Y' flag_PPBL
from tmp_customer a, tlock b
where 1=1
and a.account = b.account
and a.xchgmkt = '3'
and b.effdate <= today
and b.enddate > today
and b.reasoncode = 'PPBL'
into temp tmp_PPBL with no log;

select 'Start tmp_customer2' st, current from tcc;

select a.*
      ,case when flag_LOMB is null then 'N'
            else flag_LOMB
       end flag_LOMB
      ,case when flag_PPBL is null then 'N'
            else flag_PPBL
       end flag_PPBL
from tmp_customer a,outer tmp_LOMB b, outer tmp_PPBL c
where 1=1
and a.account = b.account
and a.account = c.account
and a.xchgmkt = '3'
into temp tmp_customer2 with no log;
create index tmp_customer2_idx on tmp_customer2(account,xchgmkt);

select 'Start tmp_customer2' st, current from tcc;

select account,max(effdate) max_effdate
from jcas
where 1=1
and tempcreditlineflag = '0'
and xchgmkt = '3'
group by 1
into temp tmp_maxjcas1 with no log;

select a.account,max_effdate,max(edittime) max_edittime
from tmp_maxjcas1 a,jcas b
where 1=1
and a.account = b.account
and a.max_effdate = b.effdate
and tempcreditlineflag = '0'
and xchgmkt = '3'
group by 1,2
into temp tmp_maxjcas with no log;

select a.*
from jcas a,tmp_maxjcas b
where 1=1
and a.account = b.account
and a.effdate = b.max_effdate
and a.edittime = b.max_edittime
and tempcreditlineflag = '0'
and xchgmkt = '3'
into temp tmp_jcas with no log;

select 'Start tmp_customer3' st, current from tcc;

select a.*,
       b.effdate line_effective,b.appcreditline
from tmp_customer2 a,outer tmp_jcas b
where a.account = b.account
and a.xchgmkt = b.xchgmkt
into temp tmp_customer3 with no log;
create index tmp_customer3_idx on tmp_customer3(account);

select 'Finish tmp_customer3' st, current from tcc;

select 'Start Update tmp_customer3' st, current from tcc;

update tmp_customer3 set appcreditline = (select appcreditline from tcas where 1=1 and xchgmkt = '3' and tmp_customer3.account = tcas.account)
where 1=1
and appcreditline is null
and account in (select account from tcas where 1=1 and xchgmkt = '3')
;
update tmp_customer3 set line_effective = (select lineeffective from tcas where 1=1 and xchgmkt = '3' and tmp_customer3.account = tcas.account)
where 1=1
and line_effective is null
and account in (select account from tcas where 1=1 and xchgmkt = '3')
;

select 'Finish Update tmp_customer3' st, current from tcc;

select 'Start tmp_customer4' st, current from tcc;

select a.*,
       '' tempcreditline_date
from tmp_customer3 a
where 1=1
into temp tmp_customer4 with no log;
create index tmp_customer4_idx on tmp_customer4(account);

select 'Finish tmp_customer4' st, current from tcc;


select a.postdate,a.account,
          a.mktval mktval_hc,a.cashbalance,a.debt
from tmg a
where 1=1
and a.xchgmkt = '3'
and a.postdate = kd_bankdate(today,-1)
into temp tmp_hc with no log;


select 'Start tmp_customer5' st, current from tcc;

select a.*,(b.mktval_hc+b.cashbalance) asset,b.debt
from tmp_customer4 a,outer tmp_hc b
where 1=1
and a.account = b.account
into temp tmp_customer5 with no log;
create index temp_customer5_idx on tmp_customer5(account);

select 'Finish tmp_customer5' st, current from tcc;

select 'Start tmp_asset' st, current from tcc;

select account,(mktval+cashbalance) asset
from tmg
where 1=1
and xchgmkt = '3'
into temp tmp_asset with no log;

select 'Finish tmp_asset' st, current from tcc;

select 'Start tmp_maxasset' st, current from tcc;

select account,max(asset) max_asset
from tmp_asset
group by 1
into temp tmp_maxasset with no log;

select 'Finish tmp_maxasset' st, current from tcc;

select 'Start tmp_maxutilizeAR' st, current from tcc;

select account,max(ar_trade/comp_creditline) max_utilizeAR 
from tmg
where 1=1
and xchgmkt = '3'
and ar_trade > 0
and comp_creditline > 0
group by 1
into temp tmp_maxutilizeAR with no log;

select 'Finish tmp_maxutilizeAR' st, current from tcc;

select 'Start tmp_maxutilizeDEBT' st, current from tcc;

select account,max(debt/comp_creditline) max_utilizedebt
from tmg
where 1=1
and xchgmkt = '3'
and debt > 0
and comp_creditline > 0
group by 1
into temp tmp_maxutilizeDEBT with no log;

select 'Finish tmp_maxutilizeDEBT' st, current from tcc;

select 'Start tmp_max' st, current from tcc;

select account
         ,case when max_asset is null then cast(0.00 as decimal(20,2))
             else max_asset 
        end max_asset
       ,cast(0.00 as decimal(20,2)) max_utilizeAR
       ,cast(0.00 as decimal(20,2)) max_utilizedebt
from tmp_maxasset 
where 1=1
union all
select account
         ,cast(0.00 as decimal(20,2)) max_asset
         ,case when max_utilizeAR is null then cast(0 as decimal(20,2))
            else max_utilizeAR
          end max_utilizeAR
         ,cast(0.00 as decimal(20,2)) max_utilizedebt
from tmp_maxutilizeAR
where 1=1
union all
select account
         ,cast(0.00 as decimal(20,2)) max_asset
         ,cast(0.00 as decimal(20,2)) max_utilizeAR
         ,case when max_utilizedebt is null then cast(0 as decimal(20,2))
                  else max_utilizedebt
          end max_utilizedebt
from tmp_maxutilizeDEBT
where 1=1
into temp tmp_max with no log;

select account
      ,cast(sum(max_asset) as decimal(20,6)) max_asset
      ,cast(sum(max_utilizeAR) as decimal(20,6)) max_utilizeAR
      ,cast(sum(max_utilizedebt) as decimal(20,6)) max_utilizedebt
from tmp_max
group by 1
into temp tmp_summax with no log;

select 'Finish tmp_max' st, current from tcc;


--unload to /NASBackup2/reviewcredit/reviewcredit2025_BOND.txt
select kd_bankdate(today,-1) asofdate
      ,a.*
      ,case when max_asset is null then 0
               else max_asset
       end max_asset
      ,case when max_utilizeAR is null then 0
              else max_utilizeAR
       end max_utilizeAR
      ,case when max_utilizedebt is null then 0
              else max_utilizedebt
       end max_utilizedebt
from tmp_customer5 a, outer tmp_summax b
where 1=1
and a.account = b.account
;
-------------------------------------------------------- BOND --------------------------------------------------------

USE [TMNEWA_DW]
GO
/****** Object:  StoredProcedure [dbo].[sp_pre_earnprem_dtl]    Script Date: 2023/6/30 下午 02:59:00 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO







CREATE       PROCEDURE [dbo].[sp_pre_earnprem_dtl] 
(
      @TXDATE   DATE
    , @nmessage VARCHAR(400) OUTPUT
)
AS


begin try
begin tran


--STEP01 分期起訖在同月份: pre_dm_earnprem_dtl_tp01
IF OBJECT_ID(N'pre_dm_earnprem_dtl_tp01') IS NOT NULL
   DROP TABLE pre_dm_earnprem_dtl_tp01;

SELECT A.dt_reference                              AS dt_reference
     , A.ipolicy1                                  AS ipolicy1
     , A.ipolicy2                                  AS ipolicy2
     , A.iendorse                                  AS iendorse
     , A.kreserve                                  AS kreserve
     , A.qperiod                                   AS qperiod
     , A.times                                     AS times
     , A.paid_times                                AS paid_times
     , A.iportfolio                                AS iportfolio 
     , A.igroup_profit                             AS igroup_profit
     , A.exp_dindem_bgn                            AS exp_dindem_bgn
     , A.exp_dindem_end                            AS exp_dindem_end
     , A.dt_period                                 AS dt_period
     , A.icohort                                   AS icohort
     , A.dwritten                                  AS dwritten
	 , CONVERT(VARCHAR(7), A.exp_dindem_bgn, 120)  AS ddate
	 , A.prem_value                                AS mearn_prem
	 , A.comm_value                                AS mearn_comm
	 , A.prem_am_value                             AS mearn_prem_adj
	 , A.comm_am_value                             AS mearn_comm_adj
  INTO pre_dm_earnprem_dtl_tp01
  FROM premium_adj_cal A

  LEFT JOIN TMNEWA_STAGE.dbo.policy_main_dtl B
    ON A.ipolicy1 = B.ipolicy1
   AND A.ipolicy2 = B.ipolicy2
   AND A.iendorse = B.iendorsement

 WHERE DATEPART(MM,CONVERT(VARCHAR(10), A.exp_dindem_bgn, 120)) = DATEPART(MM,CONVERT(VARCHAR(10), A.exp_dindem_end , 120)) --分期起訖在同月份
   AND (B.dwritten between '2021-11-01 00:00:00.000' AND '2021-11-30 00:00:00.000')--SIT測試

--STEP02 分期起訖在不同月份TYPE01: pre_dm_earnprem_dtl_tp02
IF OBJECT_ID(N'pre_dm_earnprem_dtl_tp02') IS NOT NULL
   DROP TABLE pre_dm_earnprem_dtl_tp02;

SELECT A.dt_reference                              AS dt_reference
     , A.ipolicy1                                  AS ipolicy1
     , A.ipolicy2                                  AS ipolicy2
     , A.iendorse                                  AS iendorse
     , A.kreserve                                  AS kreserve
     , A.qperiod                                   AS qperiod
     , A.times                                     AS times
     , A.paid_times                                AS paid_times
     , A.iportfolio                                AS iportfolio 
     , A.igroup_profit                             AS igroup_profit
     , A.exp_dindem_bgn                            AS exp_dindem_bgn
     , A.exp_dindem_end                            AS exp_dindem_end
     , A.dt_period                                 AS dt_period
     , A.icohort                                   AS icohort
     , A.dwritten                                  AS dwritten
	 , CONVERT(VARCHAR(7), A.exp_dindem_bgn, 120)  AS ddate
	 , A.prem_value
	 , A.comm_value
	 , A.prem_am_value
	 , A.comm_am_value
	 , FLOOR((DATEDIFF(DD, A.exp_dindem_bgn, CONVERT(DATE, DATEADD(DAY, -1, DATEADD(M, DATEDIFF(M, 0, exp_dindem_bgn)+1, 0)),23))+0.0)/DATEPART(DD, CONVERT(DATE, DATEADD(DAY, -1, DATEADD(M, DATEDIFF(M, 0, exp_dindem_bgn)+1, 0)),23))*A.prem_value)    AS mearn_prem
	 , FLOOR((DATEDIFF(DD, A.exp_dindem_bgn, CONVERT(DATE, DATEADD(DAY, -1, DATEADD(M, DATEDIFF(M, 0, exp_dindem_bgn)+1, 0)),23))+0.0)/DATEPART(DD, CONVERT(DATE, DATEADD(DAY, -1, DATEADD(M, DATEDIFF(M, 0, exp_dindem_bgn)+1, 0)),23))*A.comm_value)    AS mearn_comm
	 , FLOOR((DATEDIFF(DD, A.exp_dindem_bgn, CONVERT(DATE, DATEADD(DAY, -1, DATEADD(M, DATEDIFF(M, 0, exp_dindem_bgn)+1, 0)),23))+0.0)/DATEPART(DD, CONVERT(DATE, DATEADD(DAY, -1, DATEADD(M, DATEDIFF(M, 0, exp_dindem_bgn)+1, 0)),23))*A.prem_am_value) AS mearn_prem_adj
	 , FLOOR((DATEDIFF(DD, A.exp_dindem_bgn, CONVERT(DATE, DATEADD(DAY, -1, DATEADD(M, DATEDIFF(M, 0, exp_dindem_bgn)+1, 0)),23))+0.0)/DATEPART(DD, CONVERT(DATE, DATEADD(DAY, -1, DATEADD(M, DATEDIFF(M, 0, exp_dindem_bgn)+1, 0)),23))*A.comm_am_value) AS mearn_comm_adj
  INTO pre_dm_earnprem_dtl_tp02
  FROM premium_adj_cal A

  LEFT JOIN TMNEWA_STAGE.dbo.policy_main_dtl B
    ON A.ipolicy1 = B.ipolicy1
   AND A.ipolicy2 = B.ipolicy2
   AND A.iendorse = B.iendorsement

 WHERE DATEPART(MM,CONVERT(VARCHAR(10), A.exp_dindem_bgn, 120)) <> DATEPART(MM,CONVERT(VARCHAR(10), A.exp_dindem_end , 120)) --分期起訖在不同月份TYPE01
   AND (B.dwritten between '2021-11-01 00:00:00.000' AND '2021-11-30 00:00:00.000')--SIT測試

--STEP03 分期起訖在不同月份TYPE02: pre_dm_earnprem_dtl_tp03
IF OBJECT_ID(N'pre_dm_earnprem_dtl_tp03') IS NOT NULL
   DROP TABLE pre_dm_earnprem_dtl_tp03;


SELECT A.dt_reference                              AS dt_reference
     , A.ipolicy1                                  AS ipolicy1
     , A.ipolicy2                                  AS ipolicy2
     , A.iendorse                                  AS iendorse
     , A.kreserve                                  AS kreserve
     , A.qperiod                                   AS qperiod
     , A.times                                     AS times
     , A.paid_times                                AS paid_times
     , A.iportfolio                                AS iportfolio 
     , A.igroup_profit                             AS igroup_profit
     , A.exp_dindem_bgn                            AS exp_dindem_bgn
     , A.exp_dindem_end                            AS exp_dindem_end
     , A.dt_period                                 AS dt_period
     , A.icohort                                   AS icohort
     , A.dwritten                                  AS dwritten
	 , CONVERT(VARCHAR(7), A.exp_dindem_end, 120)  AS ddate
	 , FLOOR(A.prem_value-(DATEDIFF(DD, A.exp_dindem_bgn, DATEADD(DAY, -1, DATEADD(M, DATEDIFF(M, 0, A.exp_dindem_bgn)+1, 0)))+0.0)/DATEPART(DD,DATEADD(DAY, -1, DATEADD(M, DATEDIFF(M, 0, A.exp_dindem_bgn)+1, 0)))*A.prem_value)       AS mearn_prem
	 , FLOOR(A.comm_value-(DATEDIFF(DD, A.exp_dindem_bgn, DATEADD(DAY, -1, DATEADD(M, DATEDIFF(M, 0, A.exp_dindem_bgn)+1, 0)))+0.0)/DATEPART(DD,DATEADD(DAY, -1, DATEADD(M, DATEDIFF(M, 0, A.exp_dindem_bgn)+1, 0)))*A.comm_value)       AS mearn_comm
	 , FLOOR(A.prem_am_value-(DATEDIFF(DD, A.exp_dindem_bgn, DATEADD(DAY, -1, DATEADD(M, DATEDIFF(M, 0, A.exp_dindem_bgn)+1, 0)))+0.0)/DATEPART(DD,DATEADD(DAY, -1, DATEADD(M, DATEDIFF(M, 0, A.exp_dindem_bgn)+1, 0)))*A.prem_am_value) AS mearn_prem_adj
	 , FLOOR(A.comm_am_value-(DATEDIFF(DD, A.exp_dindem_bgn, DATEADD(DAY, -1, DATEADD(M, DATEDIFF(M, 0, A.exp_dindem_bgn)+1, 0)))+0.0)/DATEPART(DD,DATEADD(DAY, -1, DATEADD(M, DATEDIFF(M, 0, A.exp_dindem_bgn)+1, 0)))*A.comm_am_value) AS mearn_comm_adj
  INTO pre_dm_earnprem_dtl_tp03
  FROM premium_adj_cal A

  LEFT JOIN TMNEWA_STAGE.dbo.policy_main_dtl B
    ON A.ipolicy1 = B.ipolicy1
   AND A.ipolicy2 = B.ipolicy2
   AND A.iendorse = B.iendorsement

 WHERE DATEPART(MM,CONVERT(VARCHAR(10), A.exp_dindem_bgn, 120)) <> DATEPART(MM,CONVERT(VARCHAR(10), A.exp_dindem_end , 120)) --分期起訖在不同月份TYPE02
   AND (B.dwritten between '2021-11-01 00:00:00.000' AND '2021-11-30 00:00:00.000')--SIT測試

 --STEP04 INSERT pre_dm_earnprem_dtl_tp01-03 INTO pre_dm_earnprem_dtl_tp99 
IF OBJECT_ID(N'pre_dm_earnprem_dtl_tp99') IS NOT NULL
   DROP TABLE pre_dm_earnprem_dtl_tp99;

SELECT dt_reference
     , ipolicy1
     , ipolicy2
     , iendorse
     , kreserve
     , qperiod
     , times
     , paid_times
     , iportfolio
     , igroup_profit
     , exp_dindem_bgn
     , exp_dindem_end
     , dt_period
     , icohort
     , dwritten
     , ddate
     , mearn_prem
     , mearn_comm
     , mearn_prem_adj
     , mearn_comm_adj
  INTO pre_dm_earnprem_dtl_tp99
  FROM pre_dm_earnprem_dtl_tp01;

INSERT INTO pre_dm_earnprem_dtl_tp99(  
       dt_reference
     , ipolicy1
     , ipolicy2
     , iendorse
     , kreserve
     , qperiod
     , times
     , paid_times
     , iportfolio
     , igroup_profit
     , exp_dindem_bgn
     , exp_dindem_end
     , dt_period
     , icohort
     , dwritten
     , ddate
     , mearn_prem
     , mearn_comm
     , mearn_prem_adj
     , mearn_comm_adj
)
SELECT dt_reference
     , ipolicy1
     , ipolicy2
     , iendorse
     , kreserve
     , qperiod
     , times
     , paid_times
     , iportfolio
     , igroup_profit
     , exp_dindem_bgn
     , exp_dindem_end
     , dt_period
     , icohort
     , dwritten
     , ddate
     , mearn_prem
     , mearn_comm
     , mearn_prem_adj
     , mearn_comm_adj
  FROM pre_dm_earnprem_dtl_tp02;


INSERT INTO pre_dm_earnprem_dtl_tp99(  
       dt_reference
     , ipolicy1
     , ipolicy2
     , iendorse
     , kreserve
     , qperiod
     , times
     , paid_times
     , iportfolio
     , igroup_profit
     , exp_dindem_bgn
     , exp_dindem_end
     , dt_period
     , icohort
     , dwritten
     , ddate
     , mearn_prem
     , mearn_comm
     , mearn_prem_adj
     , mearn_comm_adj
)
SELECT dt_reference
     , ipolicy1
     , ipolicy2
     , iendorse
     , kreserve
     , qperiod
     , times
     , paid_times
     , iportfolio
     , igroup_profit
     , exp_dindem_bgn
     , exp_dindem_end
     , dt_period
     , icohort
     , dwritten
     , ddate
     , mearn_prem
     , mearn_comm
     , mearn_prem_adj
     , mearn_comm_adj
  FROM pre_dm_earnprem_dtl_tp03;

--STEP05 INSERT pre_dm_earnprem_dtl_tp99 INTO pre_dm_earnprem_dtl

INSERT INTO pre_dm_earnprem_dtl(   
       dt_reference
     , ipolicy1
     , ipolicy2
     , iendorse
     , kreserve
     , qperiod
     , times
     , paid_times
     , iportfolio
     , igroup_profit
     , exp_dindem_bgn
     , exp_dindem_end
     , dt_period
     , icohort
     , dwritten
     , ddate
     , mearn_prem
     , mearn_comm
     , mearn_prem_adj
     , mearn_comm_adj
)
SELECT DISTINCT
       dt_reference
     , ipolicy1
     , ipolicy2
     , iendorse
     , kreserve
     , qperiod
     , times
     , paid_times
     , iportfolio
     , igroup_profit
     , exp_dindem_bgn
     , exp_dindem_end
     , dt_period
     , icohort
     , dwritten
     , ddate
     , mearn_prem
     , mearn_comm
     , mearn_prem_adj
     , mearn_comm_adj
  FROM pre_dm_earnprem_dtl_tp99;


UPDATE SYSDB.dbo.dw_date
   SET nmessage = 'OK'
     , daction = @TXDATE
     , iupdate = 'sp_pre_earnprem_dtl'
     , dupdate = @TXDATE
 WHERE iaction = 'sp_pre_earnprem_dtl'

commit tran
   end try

 begin catch
rollback tran

UPDATE SYSDB.dbo.dw_date
   SET nmessage = left(ERROR_MESSAGE(),80)
     , iupdate = 'sp_pre_earnprem_dtl'
     , dupdate = @TXDATE
 WHERE iaction = 'sp_pre_earnprem_dtl'

end catch

SELECT @nmessage = nmessage
  FROM SYSDB.dbo.dw_date
  WHERE iaction = 'sp_pre_earnprem_dtl'

GO

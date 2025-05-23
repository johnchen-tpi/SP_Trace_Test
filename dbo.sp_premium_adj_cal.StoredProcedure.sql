USE [TMNEWA_DW]
GO
/****** Object:  StoredProcedure [dbo].[sp_premium_adj_cal]    Script Date: 2023/6/14 下午 12:47:07 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO






CREATE     PROCEDURE [dbo].[sp_premium_adj_cal]
(
      @TXDATE   DATE
    , @nmessage VARCHAR(400) OUTPUT
)
AS

 begin try
 begin tran



--STEP01 抓出DEFAULT目標手機保險預期現金流資料
IF OBJECT_ID(N'premium_adj_cal_tp01') IS NOT NULL
   DROP TABLE premium_adj_cal_tp01;

SELECT CONVERT(VARCHAR(10),DATEADD(DAY, -1, DATEADD(M, DATEDIFF(M, 0, @TXDATE)+1, 0)), 23) AS dt_reference --評估日
     , PMD.ipolicy1
     , PMD.ipolicy2
     , PMD.iendorsement
     , PMD.kreserve
     , CASE WHEN DATEDIFF(M, PMD.dindem_bgn, PMD.dindem_end) <= '12' THEN 12
            WHEN (DATEDIFF(M, PMD.dindem_bgn, PMD.dindem_end) <= '24' AND DATEDIFF(MM, PMD.dindem_bgn, PMD.dindem_end) > '12') THEN 24
            WHEN DATEDIFF(M, PMD.dindem_bgn, PMD.dindem_end) > '24' THEN 36
			ELSE 0
			 END             AS qperiod
	 , PMC.paid_times*1      AS paid_times
     , PMC.paid_times*1      AS times    --設定電信帳單期別(未來分期期數)初始值
     , PMD.iportfolio
     , PMD.igroup_profit
     , PMD.icohort
     , PM.dwritten
     , PMD.dindem_bgn
     , PMD.dindem_end
     , PM.drcv
	 , PM.qtime
	 , PM.mprem_per
	 , PM.mcomm_per
  INTO premium_adj_cal_tp01
  FROM TMNEWA_STAGE.dbo.policy_main_dtl PMD

  JOIN TMNEWA_STAGE.dbo.policy_main PM 
    ON PMD.ipolicy1 = PM.ipolicy1 
   AND PMD.ipolicy2 = PM.ipolicy2 
   AND PMD.iendorsement = PM.iendorsement

  LEFT JOIN policy_main_charge_count PMC
    ON PMD.ipolicy1 = PMC.ipolicy1
   AND PMD.ipolicy2 = PMC.ipolicy2

 WHERE (PM.iendorsement IS NULL OR PM.iendorsement = '')--保單
   AND PM.foutlist <> '1'          --未退保
   AND PM.insure_type = 'O'        --手機保險
   AND (PM.insure_kind_ply = 'HP' OR PM.insure_kind_ply = 'HD') --手機裝置 
 AND (PMD.dwritten BETWEEN '2021-11-01 00:00:00.000' AND '2021-11-30 00:00:00.000')--SIT測試用
 AND (PM.dwritten BETWEEN '2021-11-01 00:00:00.000' AND '2021-11-30 00:00:00.000') --SIT測試用
   ;


--STEP02 手機保險預期現金流資料擴展 premium_adj_cal_tp02
IF OBJECT_ID(N'premium_adj_cal_tp02') IS NOT NULL
   DROP TABLE premium_adj_cal_tp02;

CREATE TABLE [dbo].[premium_adj_cal_tp02](
	   [dt_reference] [date] NOT NULL,
	   [ipolicy1] [char](20) NOT NULL,
	   [ipolicy2] [char](20) NOT NULL,
	   [iendorsement] [char](20) NOT NULL,
	   [kreserve] [char](5) NOT NULL,
	   [qperiod] [int] NOT NULL,
	   [paid_times] [int] NOT NULL,
	   [times] [int] NOT  NULL,
	   [iportfolio] [char](10) NOT NULL,
	   [igroup_profit] [char](20) NOT NULL,
	   [icohort] [char](4) NOT NULL,
	   [dwritten] [datetime] NOT NULL,
	   [dindem_bgn] [date] NULL,
	   [dindem_end] [date] NULL,
	   [drcv] [date] NULL,
	   [qtime] [int] NULL,
	   [mprem_per] [decimal](8, 0) NULL,
	   [mcomm_per] [decimal](8, 0) NULL
) ON [PRIMARY];

DECLARE @dt_reference date
DECLARE @ipolicy1 char(20)  
DECLARE @ipolicy2 char(20)  
DECLARE @iendorsement char(20)  
DECLARE @kreserve char(5)  
DECLARE @qperiod int  
DECLARE @paid_times int 
DECLARE @times int
DECLARE @iportfolio char(10) 
DECLARE @igroup_profit char(20) 
DECLARE @icohort char(4) 
DECLARE @dwritten datetime  
DECLARE @dindem_bgn date
DECLARE @dindem_end date 
DECLARE @drcv date
DECLARE @qtime int 
DECLARE @mprem_per decimal(8,0) 
DECLARE @mcomm_per decimal(8,0) 
DECLARE @num int

DECLARE premium_adj_cal_cursor 
 CURSOR FOR 
 SELECT DISTINCT
        dt_reference
      , ipolicy1
      , ipolicy2
      , iendorsement
      , kreserve
      , qperiod
      , paid_times
      , times
      , iportfolio
      , igroup_profit
      , icohort
      , dwritten
      , dindem_bgn
      , dindem_end
      , drcv
      , qtime
      , mprem_per
      , mcomm_per
   FROM premium_adj_cal_tp01   --定義資料來源

   OPEN premium_adj_cal_cursor 
        WHILE @@FETCH_STATUS = 0 --檢查是否有讀取到資料
        BEGIN
              FETCH NEXT FROM premium_adj_cal_cursor 
			             INTO @dt_reference
						    , @ipolicy1
							, @ipolicy2
						    , @iendorsement
						    , @kreserve
						    , @qperiod
						    , @paid_times
						    , @times
						    , @iportfolio
						    , @igroup_profit
						    , @icohort
						    , @dwritten
						    , @dindem_bgn
						    , @dindem_end
						    , @drcv
						    , @qtime
						    , @mprem_per
						    , @mcomm_per   --照順序一筆一筆塞
              IF @@FETCH_STATUS <> 0 break --檢查若資料讀取完畢,則跳出迴圈      
              SET @num = 0                 --設定初始插入次數
              WHILE(@num < (@qperiod-@times+2)) --依序插入已繳期數(paid_times)到保險年期(qperiod)+1筆資料
              BEGIN
			        WHILE(@times < (@qperiod+2)) 
                    BEGIN 	             
                          INSERT INTO premium_adj_cal_tp02
			              VALUES(     @dt_reference
						            , @ipolicy1
									, @ipolicy2
						            , @iendorsement
						            , @kreserve
						            , @qperiod
						            , @paid_times
						            , @times
						            , @iportfolio
						            , @igroup_profit
						            , @icohort
						            , @dwritten
						            , @dindem_bgn
						            , @dindem_end
						            , @drcv
						            , @qtime
						            , @mprem_per
						            , @mcomm_per          ) 	 
                          SET @times = @times + 1  --每插入一筆就+1
                          SET @num = @num + 1 
	                  END
		        END
          END
   CLOSE premium_adj_cal_cursor
DEALLOCATE premium_adj_cal_cursor

--STEP03 插入premium_adj_cal_tp03 
IF OBJECT_ID(N'premium_adj_cal_tp03') IS NOT NULL
   DROP TABLE premium_adj_cal_tp03;

SELECT dt_reference
     , ipolicy1
     , ipolicy2
     , iendorsement
     , kreserve
     , qperiod
     , paid_times
     , times
     , iportfolio
     , igroup_profit
     , icohort
     , dwritten
     , dindem_bgn
     , dindem_end
     , drcv
     , qtime
     , mprem_per
     , mcomm_per
  INTO premium_adj_cal_tp03
  FROM premium_adj_cal_tp02 ;



--STEP04 手機保險預期現金流資料計算處理(1)premium_adj_cal_tp04-分期保障起日/分期保障迄日/現金流帳務日期 
IF OBJECT_ID(N'premium_adj_cal_tp04') IS NOT NULL
   DROP TABLE premium_adj_cal_tp04;

SELECT PAC.dt_reference
     , PAC.ipolicy1
     , PAC.ipolicy2
     , PAC.iendorsement
     , PAC.kreserve
     , PAC.qperiod
     , PAC.paid_times
     , PAC.times
     , PAC.iportfolio
     , PAC.igroup_profit
     , PAC.icohort
     , PAC.dwritten
     , PAC.dindem_bgn
     , PAC.dindem_end
     , PAC.drcv
     , PAC.qtime
     , PAC.mprem_per
     , PAC.mcomm_per
     , CASE WHEN PAC.times = '1'  THEN CONVERT(VARCHAR(10),PAC.dindem_bgn, 23) 
	        WHEN PAC.times >= '2' THEN CONCAT(CONVERT(VARCHAR(7), DATEADD(MM, PAC.times-2, PAC.dindem_bgn), 23), '-', '20') --初版取CONCAT(REPLICATE('0', (2-LEN(CONVERT(VARCHAR(2), DATEPART(DD,DATEADD(DD, 1, PAC.drcv)))))), DATEPART(DD,DATEADD(DD, 1, PAC.drcv))),改20號
            ELSE NULL 
		  END         AS exp_dindem_bgn
     , CASE WHEN DATEPART(DD, PAC.dindem_bgn) < DATEPART(DD, PAC.drcv) 
	        THEN
	             CASE WHEN PAC.times = '1'  THEN CONVERT(VARCHAR(10),PAC.drcv, 23)   --取當月結算日
			          WHEN PAC.times >= '2' THEN CONCAT(CONVERT(VARCHAR(7), DATEADD(MM, PAC.times-1, PAC.dindem_bgn), 23), '-', '20')  --初版取dindem_bgn+(P-1)個月+結算日CONCAT(REPLICATE('0', (2-LEN(CONVERT(VARCHAR(2), DATEPART(DD,PAC.drcv))))), DATEPART(DD,PAC.drcv)) >> 改取dindem_bgn+(P-1)個月+20號
			          ELSE NULL 
		               END
	        ELSE(CASE WHEN PAC.times = '1'  THEN CONCAT(CONVERT(VARCHAR(7), DATEADD(MM, 1, PAC.dindem_bgn), 23), '-', '20') --初版取dindem_bgn+1個月+結算日CONCAT(REPLICATE('0', (2-LEN(CONVERT(VARCHAR(2), DATEPART(DD,PAC.drcv))))), DATEPART(DD,PAC.drcv))>> 改取dindem_bgn+1個月+20號
			          WHEN PAC.times >= '2' THEN CONCAT(CONVERT(VARCHAR(7), DATEADD(MM, PAC.times, PAC.dindem_bgn), 23), '-', '20') --初版取dindem_bgn+P個月+結算日CONCAT(REPLICATE('0', (2-LEN(CONVERT(VARCHAR(2), DATEPART(DD,PAC.drcv))))), DATEPART(DD,PAC.drcv))>> 改取dindem_bgn+P個月+20號
			          ELSE NULL 
		               END 
				)
			 END      AS exp_dindem_end
     , DATEADD(MM, (PAC.times-PAC.paid_times), PAC.drcv)      AS dt_period
     , DPF.retention_rate
  INTO premium_adj_cal_tp04
  FROM premium_adj_cal_tp03 PAC

  LEFT JOIN dm_prem_factor DPF
    ON PAC.kreserve = DPF.kreserve
   AND PAC.icohort = DPF.iyear
   AND PAC.qperiod = DPF.qperiod
   AND PAC.times = DPF.times
   AND PAC.paid_times = DPF.paid_times;

--STEP05 手機保險預期現金流資料計算處理(2)premium_adj_cal_tp05-(原始)佣金與保費計算第一期與其他
IF OBJECT_ID(N'premium_adj_cal_tp05') IS NOT NULL
   DROP TABLE premium_adj_cal_tp05;
  
SELECT dt_reference
     , ipolicy1
     , ipolicy2
     , iendorsement
     , kreserve
     , qperiod
     , paid_times
     , times
     , iportfolio
     , igroup_profit
     , icohort
     , dwritten
     , dindem_bgn
     , dindem_end
     , drcv
     , qtime
     , mprem_per
     , mcomm_per
     , exp_dindem_bgn
     , exp_dindem_end
     , dt_period
     , retention_rate
	 , CASE WHEN times = '1'
	        THEN mprem_per*qtime*DATEDIFF(DD, exp_dindem_bgn, exp_dindem_end)/DATEDIFF(DD, dindem_bgn, dindem_end) --先做第一期
		    ELSE mprem_per   --末期與中間
	         END             AS prem_value
	 , CASE WHEN times = '1'
	        THEN mcomm_per*qtime*DATEDIFF(DD, exp_dindem_bgn, exp_dindem_end)/DATEDIFF(DD, dindem_bgn, dindem_end) --先做第一期
		    ELSE mcomm_per   --末期與中間
	         END             AS comm_value
  INTO premium_adj_cal_tp05
  FROM premium_adj_cal_tp04;
  
--STEP06 手機保險預期現金流資料計算處理(3)premium_adj_cal_tp06-(原始)佣金與保費計算末期
IF OBJECT_ID(N'premium_adj_cal_tp06') IS NOT NULL
   DROP TABLE premium_adj_cal_tp06;

SELECT A.dt_reference
     , A.ipolicy1
     , A.ipolicy2
     , A.iendorsement
     , A.kreserve
     , A.qperiod
     , A.paid_times
     , A.times
     , A.iportfolio
     , A.igroup_profit
     , A.icohort
     , A.dwritten
     , A.dindem_bgn
     , A.dindem_end
     , A.drcv
     , A.qtime
     , A.mprem_per
     , A.mcomm_per
     , A.exp_dindem_bgn
     , A.exp_dindem_end
     , A.dt_period
     , A.retention_rate
	 , CASE WHEN A.qperiod+1 = A.times  --找出末期
	        THEN A.mprem_per-B.prem_value+0.0
			ELSE A.prem_value
			 END                                      AS prem_value
	 , CASE WHEN A.qperiod+1 = A.times  --找出末期
	        THEN A.mcomm_per-B.comm_value+0.0
			ELSE A.comm_value
			 END                                      AS comm_value
  INTO premium_adj_cal_tp06
  FROM premium_adj_cal_tp05 A
  
  LEFT JOIN (SELECT * 
               FROM premium_adj_cal_tp05

		      WHERE paid_times = times     --找出第一期
	        ) B
    ON A.dt_reference = B.dt_reference
   AND A.ipolicy1 = B.ipolicy1
   AND A.ipolicy2 = B.ipolicy2
   AND A.iendorsement = B.iendorsement
   AND A.kreserve = B.kreserve
   AND A.qperiod = B.qperiod
   AND A.paid_times = B.paid_times
   AND A.iportfolio = B.iportfolio
   AND A.igroup_profit = B.igroup_profit
   AND A.icohort = B.icohort;

--STEP07 手機保險預期現金流資料計算處理(4)premium_adj_cal_tp99-保費金額(考量存續率)與佣金金額(考量存續率)計算
IF OBJECT_ID(N'premium_adj_cal_tp99') IS NOT NULL
   DROP TABLE premium_adj_cal_tp99;

SELECT dt_reference               
     , ipolicy1
     , ipolicy2
     , iendorsement                AS iendorse 
     , kreserve
     , qperiod
	 , times
     , paid_times
     , iportfolio
     , igroup_profit
     , icohort
     , dwritten
     , exp_dindem_bgn
     , exp_dindem_end
     , dt_period
	 , prem_value
	 , comm_value    
	 , prem_value*retention_rate   AS prem_am_value
	 , comm_value*retention_rate   AS comm_am_value 
  INTO premium_adj_cal_tp99
  FROM premium_adj_cal_tp06 ;

--STEP08 將已繳期別去除再插入Target Table
INSERT INTO premium_adj_cal(
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
          , icohort
          , dwritten
          , exp_dindem_bgn
          , exp_dindem_end
          , dt_period
          , prem_value
          , comm_value    
          , prem_am_value
          , comm_am_value 
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
     , icohort 
     , CONVERT(DATE, dwritten, 23)         AS dwritten
     , exp_dindem_bgn
     , exp_dindem_end
     , dt_period
     , prem_value
     , comm_value    
     , prem_am_value
     , comm_am_value 
  FROM premium_adj_cal_tp99 
  
WHERE paid_times <> times ;  --將已繳期別去除;


UPDATE SYSDB.dbo.dw_date
   SET nmessage = 'OK'
     , daction = @TXDATE
     , iupdate = 'sp_premium_adj_cal'
     , dupdate = @TXDATE
 WHERE iaction = 'sp_premium_adj_cal'

commit tran
   end try

 begin catch
rollback tran

UPDATE SYSDB.dbo.dw_date
   SET nmessage = left(ERROR_MESSAGE(),80)
     , iupdate = 'sp_premium_adj_cal'
     , dupdate = @TXDATE
 WHERE iaction = 'sp_premium_adj_cal'
 end catch

 SELECT @nmessage = nmessage
  FROM SYSDB.dbo.dw_date


 WHERE iaction = 'sp_premium_adj_cal'


GO

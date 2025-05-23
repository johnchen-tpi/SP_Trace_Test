USE [TMNEWA_DW]
GO
/****** Object:  StoredProcedure [dbo].[sp_dm_prem_factor]    Script Date: 2023/6/14 下午 12:47:07 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO





CREATE    PROCEDURE [dbo].[sp_dm_prem_factor] 
(
      @TXDATE   DATE
    , @nmessage VARCHAR(400) OUTPUT
)
AS

begin try
begin tran

--STEP01 產生初始Default paid_times已繳期別(T)=0 之資料進dm_prem_factor_tp01
IF OBJECT_ID(N'dm_prem_factor_tp01') IS NOT NULL
   DROP TABLE dm_prem_factor_tp01;

SELECT insure_type                
     , insure_kind_ply                        
     , kreserve                       
     , iyear                       
     , qperiod                       
     , times                       
     , 0                        AS paid_times
	 , retention_rate
  INTO dm_prem_factor_tp01
  FROM TMNEWA_STAGE.dbo.prem_factor
 WHERE iyear='2021'--SIT測試

--STEP02 存續率資料擴展 dm_prem_factor_tp02
IF OBJECT_ID(N'dm_prem_factor_tp02') IS NOT NULL
   DROP TABLE dm_prem_factor_tp02;

CREATE TABLE dm_prem_factor_tp02(
   	   [insure_type] [char](1) NOT NULL,
   	   [insure_kind_ply] [char](6) NOT NULL,
   	   [kreserve] [char](5) NOT NULL,
   	   [iyear] [char](4) NOT NULL,
   	   [qperiod] [int] NOT NULL,
   	   [times] [int] NOT NULL,
   	   [paid_times] [int] NOT NULL,
   	   [retention_rate] [decimal](8, 5) NOT NULL
) ON [PRIMARY];

DECLARE @insure_type  char(1)
DECLARE @insure_kind_ply char(6)
DECLARE @kreserve char(5)
DECLARE @iyear char(4)
DECLARE @qperiod int
DECLARE @times int
DECLARE @paid_times int
DECLARE @retention_rate decimal(8,5)
DECLARE @num int

DECLARE dm_prem_factor_cursor 
 CURSOR FOR 
 SELECT insure_type                    
      , insure_kind_ply                        
      , kreserve                       
      , iyear                       
      , qperiod                       
      , times                       
      , paid_times
	  , retention_rate
   FROM dm_prem_factor_tp01   --定義資料來源

   OPEN dm_prem_factor_cursor 
        WHILE @@FETCH_STATUS = 0 --檢查是否有讀取到資料
        BEGIN
              FETCH NEXT FROM dm_prem_factor_cursor INTO @insure_type, @insure_kind_ply, @kreserve, @iyear, @qperiod, @times, @paid_times, @retention_rate  --照順序一筆一筆塞
		      IF @@FETCH_STATUS <> 0 break --檢查若資料讀取完畢,則跳出迴圈
			  SET @num = 0         --設定初始插入次數
			  IF(@num = @times-1)  --依據times欄位之值設定插入paid_times次數
			  BEGIN
			       INSERT INTO dm_prem_factor_tp02
			       VALUES(@insure_type, @insure_kind_ply, @kreserve, @iyear, @qperiod, @times, @paid_times, @retention_rate)
				END
			  ELSE
			  BEGIN
		            WHILE(@num < @times-1) --依據times欄位之值設定插入paid_times次數
			        BEGIN
			              WHILE(@paid_times < @times) 
                          BEGIN 	                          
                                INSERT INTO dm_prem_factor_tp02
			                    VALUES(@insure_type, @insure_kind_ply, @kreserve, @iyear, @qperiod, @times, @paid_times, @retention_rate)
						        SET @paid_times = @paid_times + 1  --每插入一筆就+1
			                    SET @num = @num + 1 
	                        END
		               END
				END
		   END
   CLOSE dm_prem_factor_cursor
DEALLOCATE dm_prem_factor_cursor;


--STEP03 存續率計算處理(1): 欄位拆分dm_prem_factor_tp02 >> dm_prem_factor_tp03(不包含T=0)
IF OBJECT_ID(N'dm_prem_factor_tp03') IS NOT NULL
   DROP TABLE dm_prem_factor_tp03;

 SELECT TP02.insure_type                    
      , TP02.insure_kind_ply                        
      , TP02.kreserve                       
      , TP02.iyear                       
      , TP02.qperiod                       
      , TP02.times                       
      , TP02.paid_times
	  , TP02.retention_rate               AS "Pt+1_T0"   --取(帳單期數P=t+1期且T=0的存續率)當計算分子
	  , TP02.retention_rate               AS Pt_T0       --取(帳單期數P=t期且T=0的存續率)當計算分母 
   INTO dm_prem_factor_tp03
   FROM dm_prem_factor_tp02 TP02;


--STEP04 存續率計算處理(2): 計算存續率dm_prem_factor_tp03 >> dm_prem_factor_tp04(不包含T=0)
IF OBJECT_ID(N'dm_prem_factor_tp04') IS NOT NULL
   DROP TABLE dm_prem_factor_tp04;

SELECT TP03.insure_type                    
     , TP03.insure_kind_ply                        
     , TP03.kreserve                       
     , TP03.iyear                       
     , TP03.qperiod                       
     , TP03.times                       
     , TP03.paid_times
	 , TP03."Pt+1_T0"   
	 , TP01.retention_rate      AS Pt_T0
  INTO dm_prem_factor_tp04
  FROM dm_prem_factor_tp03 TP03

  JOIN (SELECT insure_type                    
             , insure_kind_ply                        
             , kreserve                       
             , iyear                       
             , qperiod                                          
             , times          AS paid_times  --因為tp03分母值要回去找原始Pt且T=0之值, 因此將tp01初始P(times)當成T(paid_times),才能使tp03各單位計算分母欄位對到tp01相應的原始Pt且T=0之值
             , retention_rate       
		  FROM dm_prem_factor_tp01
       )TP01
    ON TP03.insure_type = TP01.insure_type                  
   AND TP03.insure_kind_ply = TP01.insure_kind_ply                        
   AND TP03.kreserve = TP01.kreserve                       
   AND TP03.iyear = TP01.iyear                       
   AND TP03.qperiod = TP01.qperiod                       
   AND TP03.paid_times = TP01.paid_times;

--STEP05 存續率計算處理(3): 計算存續率dm_prem_factor_tp01 + dm_prem_factor_tp04 >> dm_prem_factor_tp99
IF OBJECT_ID(N'dm_prem_factor_tp99') IS NOT NULL
   DROP TABLE dm_prem_factor_tp99;

SELECT S.insure_type                    
     , S.insure_kind_ply                        
     , S.kreserve                       
     , S.iyear                       
     , S.qperiod                       
     , S.times                       
     , S.paid_times
	 , S.retention_rate
  INTO dm_prem_factor_tp99
  FROM(
SELECT TP04.insure_type                    
     , TP04.insure_kind_ply                        
     , TP04.kreserve                       
     , TP04.iyear                       
     , TP04.qperiod                       
     , TP04.times                       
     , TP04.paid_times
	 , TP04."Pt+1_T0"/TP04.Pt_T0*100  AS retention_rate
  FROM dm_prem_factor_tp04 TP04

 UNION 

SELECT TP01.insure_type                    
     , TP01.insure_kind_ply                        
     , TP01.kreserve                       
     , TP01.iyear                       
     , TP01.qperiod                       
     , TP01.times                       
     , TP01.paid_times
	 , TP01.retention_rate
  FROM dm_prem_factor_tp01 TP01
)S

--STEP06 dm_prem_factor_tp99進[dbo].[dm_prem_factor]
INSERT INTO dm_prem_factor(
            insure_type
          , insure_kind_ply
          , kreserve
          , iyear
          , qperiod
          , times
          , paid_times
          , retention_rate
)
SELECT insure_type
     , insure_kind_ply
     , kreserve
     , iyear
     , qperiod
     , times
     , paid_times
     , retention_rate
  FROM dm_prem_factor_tp99 TP99 


 UPDATE SYSDB.dbo.dw_date
    SET nmessage = 'OK'
      , daction = @TXDATE
      , iupdate = 'sp_dm_prem_factor'
      , dupdate = @TXDATE
  WHERE iaction = 'sp_dm_prem_factor'

 commit tran
   end try
   
   begin catch
rollback tran

UPDATE SYSDB.dbo.dw_date
   SET nmessage = left(ERROR_MESSAGE(),80)
     , iupdate = 'sp_dm_prem_factor'
     , dupdate = @TXDATE
 WHERE iaction = 'sp_dm_prem_factor'

end catch
--- Commit Tran

SELECT @nmessage = nmessage
  FROM SYSDB.dbo.dw_date


 WHERE iaction = 'sp_dm_prem_factor'

GO

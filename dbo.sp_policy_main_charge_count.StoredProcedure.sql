USE [TMNEWA_DW]
GO
/****** Object:  StoredProcedure [dbo].[sp_policy_main_charge_count]    Script Date: 2023/6/14 下午 12:47:07 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO





CREATE      PROCEDURE [dbo].[sp_policy_main_charge_count]
(
      @TXDATE   DATE
    , @nmessage VARCHAR(400) OUTPUT
)
AS

begin try
begin tran


INSERT INTO [dbo].[policy_main_charge_count]( 
            ipolicy1		
           ,ipolicy2		
           ,paid_times
)

SELECT DISTINCT
       A.ipolicy1		    AS		ipolicy1
      ,A.ipolicy2		    AS		ipolicy2
      ,count(*) OVER (PARTITION BY B.ipolicy1,B.ipolicy2)			AS		paid_times 
FROM TMNEWA_STAGE.dbo.policy_main_charge A
JOIN TMNEWA_STAGE.dbo.policy_main B
ON A.ipolicy1 = B.ipolicy1 
AND  A.ipolicy2 = B.ipolicy2
and A.iendorse = B.iendorsement
WHERE B.insure_type = 'O'
and (B.insure_kind_ply = 'HP' or B.insure_kind_ply = 'HD')
and (B.dwritten between '2021-12-01 00:00:00.000'and '2021-12-31 00:00:00.000')--SIT測試
and (A.dpay BETWEEN '2021-12-01' AND '2021-12-31' )--SIT測試


UPDATE SYSDB.dbo.dw_date
   SET nmessage = 'OK'
     , daction = @TXDATE
     , iupdate = 'sp_policy_main_charge_count'
     , dupdate = @TXDATE
 WHERE iaction = 'sp_policy_main_charge_count'

commit tran
   end try

 begin catch
rollback tran

UPDATE SYSDB.dbo.dw_date
   SET nmessage = left(ERROR_MESSAGE(),80)
     , iupdate = 'sp_policy_main_charge_count'
     , dupdate = @TXDATE
 WHERE iaction = 'sp_policy_main_charge_count'

end catch
SELECT @nmessage = nmessage
  FROM SYSDB.dbo.dw_date
 WHERE iaction = 'sp_policy_main_charge_count'

GO

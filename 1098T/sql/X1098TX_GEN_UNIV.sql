USE coll18_test1
set transaction isolation level read uncommitted


IF  EXISTS (SELECT * FROM sys.objects 
WHERE object_id = OBJECT_ID(N'[dbo].[X1098TX_GEN_UNIV]') AND type in (N'P', N'PC'))
 DROP PROCEDURE [dbo].X1098TX_GEN_UNIV
GO
 
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

/***************************************************************************************************
 Name: X1098TX_GEN_UNIV
 Purpose: Returns a set of student IDs that are used as the base universe population 
          to be used when generating the 1098T Workfile in Colleague (T9TG).
		  With the generated set, create a savedlist in Colleague, and provide
		  savedlist name to user.
		  Execution times varies, but an estimate is 1 minute.

 Maint log
 Ver    Date      Author      Description
 -----------------------------------------
 1.0  12/14/22  cschultz  
 For now just a straight query to be used immediately for Tax year 2022. 
 Will convert to proc later. 
 
 1.1  12/19/22  cschultz  
 Modified query so that students with residency status A and F
 are included only if they have a non-empty SSN.
 Any other student residency is in, regardless of whether SSN is empty or not.
 
 1.2  3/9/23   cschultz
 Converted to proc.
**************************************************************************************************/
CREATE  PROCEDURE dbo.X1098TX_GEN_UNIV (
  @P_TAX_YEAR  VARCHAR(4)
  )
AS BEGIN


  -- SET NOCOUNT ON added to prevent extra result sets from
  -- interfering with SELECT statements.
  SET NOCOUNT ON

  DECLARE @V_PROC_NAME  VARCHAR(50) = 'X1098TX_GEN_UNIV'
  DECLARE @LINE NUMERIC(3) 
  DECLARE @V_MSG VARCHAR(500) 


  DECLARE @V_PREV_YEAR VARCHAR(4)
  DECLARE @STC_START_DATE_LOWER_LIMIT  VARCHAR(8) 
  DECLARE @CNT NUMERIC(10) 
  DECLARE @V_OPERATOR VARCHAR(30) 

  SELECT  @V_OPERATOR = left(SYSTEM_USER,30)  -- user running this 

  BEGIN TRY
	SET @LINE =1
	SET @V_MSG='Begin @P_TAX_YEAR: ' + @P_TAX_YEAR 
	EXEC dbo.X1098T_LOG_DEBUG @P_TAX_YEAR, @V_PROC_NAME, @LINE, @V_MSG,  0, @V_OPERATOR                


	SET  @V_PREV_YEAR = CONVERT(VARCHAR(4), CONVERT(NUMERIC(4), @P_TAX_YEAR) -1)
	SET @V_MSG='@V_PREV_YEAR: ' + @V_PREV_YEAR 
	--EXEC dbo.X1098T_LOG_DEBUG @P_TAX_YEAR, @V_PROC_NAME, @LINE, @V_MSG,  0, @V_OPERATOR                


	SET  @STC_START_DATE_LOWER_LIMIT  = @V_PREV_YEAR + '0701'  
	SET @V_MSG='@STC_START_DATE_LOWER_LIMIT= |' + @STC_START_DATE_LOWER_LIMIT + '|'
	--EXEC dbo.X1098T_LOG_DEBUG @P_TAX_YEAR, @V_PROC_NAME, @LINE, @V_MSG,  0, @V_OPERATOR                

	-- Load base data
	SET @LINE =10

	CREATE TABLE #XT98T_UNIV_TEMP
	(TAX_YEAR VARCHAR(4) collate Latin1_General_BIN NOT NULL,   
	STC_PERSON_ID VARCHAR(7)  collate Latin1_General_BIN NOT NULL,  
	STU_RESIDENCY_STATUS VARCHAR(5) collate Latin1_General_BIN NULL, 
	SSN VARCHAR(12) collate Latin1_General_BIN,   
	INCLUDE_FLAG NUMERIC(1,0))

	INSERT INTO #XT98T_UNIV_TEMP (TAX_YEAR, STC_PERSON_ID)
		SELECT @P_TAX_YEAR, SAC.STC_PERSON_ID
		FROM STUDENT_ACAD_CRED SAC  WITH (NOLOCK) 
		INNER JOIN STC_STATUSES SACS  WITH (NOLOCK) ON  SAC.STUDENT_ACAD_CRED_ID=SACS.STUDENT_ACAD_CRED_ID  
		INNER JOIN STUDENT_COURSE_SEC SCS WITH (NOLOCK)  ON SAC.STUDENT_ACAD_CRED_ID=SCS.SCS_STUDENT_ACAD_CRED  
		INNER JOIN COURSE_SECTIONS CS WITH (NOLOCK) ON SCS.SCS_COURSE_SECTION= CS.COURSE_SECTIONS_ID 
		WHERE  
		SACS.POS=1   
		
		--  college credit course 
	    AND CS.SEC_ACAD_LEVEL='CC'    
  
		--  cred type
		AND SAC.STC_CRED_TYPE  IN ('AR','C', 'CBE', 'D','MR','NFR','R')  
  
		-- with a positive number of units
		AND SAC.STC_CRED >0  
  
		-- from july of prior year  
		AND CONVERT(VARCHAR(8),SAC.STC_START_DATE,112) >= @STC_START_DATE_LOWER_LIMIT  

		GROUP BY SAC.STC_PERSON_ID


	SET @V_MSG='loaded base..'
	EXEC dbo.X1098T_LOG_DEBUG @P_TAX_YEAR, @V_PROC_NAME, @LINE, @V_MSG,  0, @V_OPERATOR                
 

	-- Update SSN
	SET @LINE =20
  
	UPDATE U
	SET SSN = P.SSN 
	FROM #XT98T_UNIV_TEMP  U
	INNER JOIN PERSON P  WITH (NOLOCK) ON U.STC_PERSON_ID COLLATE DATABASE_DEFAULT  = P.ID  COLLATE DATABASE_DEFAULT 

	SET @V_MSG='updated SSNs..'
	EXEC dbo.X1098T_LOG_DEBUG @P_TAX_YEAR, @V_PROC_NAME, @LINE, @V_MSG,  0, @V_OPERATOR                


	-- Update resid status
	SET @LINE =30

	UPDATE U
		SET STU_RESIDENCY_STATUS = R.STU_RESIDENCY_STATUS
		FROM #XT98T_UNIV_TEMP  U
		INNER JOIN STU_RESIDENCIES R WITH (NOLOCK) ON U.STC_PERSON_ID COLLATE DATABASE_DEFAULT  = R.STUDENTS_ID COLLATE DATABASE_DEFAULT 
		WHERE R.POS=1

	SET @V_MSG='updated STU_RESIDENCY_STATUS..'
	EXEC dbo.X1098T_LOG_DEBUG @P_TAX_YEAR, @V_PROC_NAME, @LINE, @V_MSG,  0, @V_OPERATOR                


	-- update nulls
	SET @LINE =32

	UPDATE  #XT98T_UNIV_TEMP  
	SET  STU_RESIDENCY_STATUS=ISNULL(STU_RESIDENCY_STATUS,''), SSN =ISNULL(SSN,'')



	-- A OR F are include only if SSN is non empty
	SET @LINE =34

	UPDATE  #XT98T_UNIV_TEMP
	SET INCLUDE_FLAG=1
	WHERE
	STU_RESIDENCY_STATUS IN ('A','F') AND SSN <> ''

	SET @V_MSG='updated INCLUDE_FLAG for A and F..'
	EXEC dbo.X1098T_LOG_DEBUG @P_TAX_YEAR, @V_PROC_NAME, @LINE, @V_MSG,  0, @V_OPERATOR                



	-- the rest (non A or F) qualify regardless of whether they have SSN or not
	SET @LINE =36
  
	UPDATE  #XT98T_UNIV_TEMP
	SET INCLUDE_FLAG=1
	WHERE
	STU_RESIDENCY_STATUS NOT IN ('A','F')

	SET @V_MSG='updated INCLUDE_FLAG for non (A and F)..'
	EXEC dbo.X1098T_LOG_DEBUG @P_TAX_YEAR, @V_PROC_NAME, @LINE, @V_MSG,  0, @V_OPERATOR                


	-- update nulls for INCLUDE_FLAG
    SET @LINE =36
  
    UPDATE  #XT98T_UNIV_TEMP  SET  INCLUDE_FLAG=ISNULL(INCLUDE_FLAG,0)

	-- list the records
	SET @LINE =38
  
	SELECT @CNT = COUNT(*)  FROM #XT98T_UNIV_TEMP WHERE INCLUDE_FLAG=1

	SET @V_MSG='Completed. # of students in universe: ' + convert(varchar(10), @CNT)
	EXEC dbo.X1098T_LOG_DEBUG @P_TAX_YEAR, @V_PROC_NAME, @LINE, @V_MSG,  0, @V_OPERATOR                

  END TRY

  BEGIN CATCH
    SET @V_MSG =  'Exception caught in ' + @V_PROC_NAME    + ': ' + error_message() + ' Line# : ' + LTRIM(STR(@LINE))
    EXEC dbo.X1098T_LOG_DEBUG @P_TAX_YEAR, @V_PROC_NAME, @LINE, @V_MSG,  0, @V_OPERATOR                
  END CATCH


  -- Data for savedlist
  -- ------------------
  SELECT STC_PERSON_ID FROM #XT98T_UNIV_TEMP WHERE INCLUDE_FLAG=1 ORDER BY STC_PERSON_ID
END


GO
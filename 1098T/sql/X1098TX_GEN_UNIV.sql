USE coll18_live
set transaction isolation level read uncommitted

-- *************************************************************************************
-- X1098T_GEN_UNIV
-- Generate universe population for 1098T
--
-- 12/19/22
-- For now Tax Year 2022, will convert to proc later 
-- Modify query so that students with residency status A and F
-- are included only if they have a non-empty SSN.
-- Any other student residency is in, regardless of whether SSN is empty or not.
-- *************************************************************************************

DECLARE @TAX_YEAR VARCHAR(4) = '2022'
DECLARE  @STC_START_DATE_LOWER_LIMIT  VARCHAR(8) = '20210701'

 
-- JUST THE IDs
-- --------------------
-- DROP TABLE #XT98T_UNIV_TEMP

CREATE TABLE #XT98T_UNIV_TEMP
(TAX_YEAR VARCHAR(4) collate Latin1_General_BIN NOT NULL,   
STC_PERSON_ID VARCHAR(7)  collate Latin1_General_BIN NOT NULL,  
STU_RESIDENCY_STATUS VARCHAR(5) collate Latin1_General_BIN NULL, 
SSN VARCHAR(12) collate Latin1_General_BIN,   
INCLUDE_FLAG NUMERIC(1,0))



INSERT INTO #XT98T_UNIV_TEMP (TAX_YEAR, STC_PERSON_ID)
 SELECT @TAX_YEAR, SAC.STC_PERSON_ID
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

PRINT 'loaded base..'
 
 --SELECT * FROM  #XT98T_UNIV_TEMP 

-- UPDATE SSN
UPDATE U
SET SSN = P.SSN 
FROM #XT98T_UNIV_TEMP  U
INNER JOIN PERSON P  WITH (NOLOCK) ON U.STC_PERSON_ID COLLATE DATABASE_DEFAULT  = P.ID  COLLATE DATABASE_DEFAULT 

PRINT 'updated SSNs..'

--SELECT * FROM  #XT98T_UNIV_TEMP 

-- UPDATE RESID STATUS
UPDATE U
SET STU_RESIDENCY_STATUS = R.STU_RESIDENCY_STATUS
FROM #XT98T_UNIV_TEMP  U
INNER JOIN STU_RESIDENCIES R WITH (NOLOCK) ON U.STC_PERSON_ID COLLATE DATABASE_DEFAULT  = R.STUDENTS_ID COLLATE DATABASE_DEFAULT 
WHERE R.POS=1

PRINT 'updated STU_RESIDENCY_STATUS..'


-- UPDATE NULLS
UPDATE  #XT98T_UNIV_TEMP  
SET  STU_RESIDENCY_STATUS=ISNULL(STU_RESIDENCY_STATUS,''), SSN =ISNULL(SSN,'')



-- A OR F ARE INCLUDE ONLY IF SSN IS NON EMPTY
UPDATE  #XT98T_UNIV_TEMP
SET INCLUDE_FLAG=1
WHERE
STU_RESIDENCY_STATUS IN ('A','F') AND SSN <> ''

PRINT 'updated INCLUDE_FLAG for A and F..'

--SELECT * FROM  #XT98T_UNIV_TEMP ORDER BY STU_RESIDENCY_STATUS


-- THE REST (NON A OR F) QUALIFY REGARDLESS OF WHETHER THEY HAVE SS OR NOT
UPDATE  #XT98T_UNIV_TEMP
SET INCLUDE_FLAG=1
WHERE
STU_RESIDENCY_STATUS NOT IN ('A','F')

PRINT 'updated INCLUDE_FLAG for non (A and F)..'

-- UPDATE NULLS FOR INCLUDE_FLAG
UPDATE  #XT98T_UNIV_TEMP  SET  INCLUDE_FLAG=ISNULL(INCLUDE_FLAG,0)





-- LIST THE RECORDS

declare @CNT NUMERIC(10) 
SELECT @CNT = COUNT(*)  FROM #XT98T_UNIV_TEMP WHERE INCLUDE_FLAG=1

-- 1/4/23 11:50 am. PROD
-- All done.. Number of records: 72983
PRINT 'All done.. Number of records: ' + convert(varchar(10), @CNT)

SELECT * FROM  #XT98T_UNIV_TEMP WHERE INCLUDE_FLAG=1  ORDER BY STU_RESIDENCY_STATUS


-- Data for savedlist
-- 71K for test1
-- %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
SELECT STC_PERSON_ID FROM #XT98T_UNIV_TEMP WHERE INCLUDE_FLAG=1 ORDER BY STC_PERSON_ID






-- -----------------------------------------

/* 

-- residency status
SELECT * FROM STU_RESIDENCIES SR2 WITH (NOLOCK)
WHERE STU_RESIDENCY_STATUS IS NOT NULL
ORDER BY STUDENTS_ID, POS


STUDENTS_ID	POS	STU_RESIDENCY_STATUS
1025477	1	R
1025477	2	CER





-- DETAIL
 -- ------------------------------
DECLARE @TAX_YEAR VARCHAR(4) = '2022'
DECLARE  @STC_START_DATE_LOWER_LIMIT  VARCHAR(8) = '20210701'

SELECT SAC.STC_PERSON_ID, SAC.STC_TERM,   SCS.SCS_COURSE_SECTION,  
SAC.STC_COURSE_NAME + '-' + STC_SECTION_NO,   SCS.STUDENT_COURSE_SEC_ID,  SAC.STUDENT_ACAD_CRED_ID, 
CONVERT(VARCHAR(8),SACS.STC_STATUS_DATE,1),  SACS.STC_STATUS,    
 CASE SACS.STC_STATUS   WHEN 'A' THEN  'ADD'  WHEN 'N' THEN 'NEW' ELSE SACS.STC_STATUS  END,   
   SAC.STC_CRED
FROM STUDENT_ACAD_CRED SAC  WITH (NOLOCK) 
 INNER JOIN STC_STATUSES SACS  WITH (NOLOCK) ON  SAC.STUDENT_ACAD_CRED_ID=SACS.STUDENT_ACAD_CRED_ID  
 INNER JOIN STUDENT_COURSE_SEC SCS WITH (NOLOCK)  ON SAC.STUDENT_ACAD_CRED_ID=SCS.SCS_STUDENT_ACAD_CRED  
 INNER JOIN COURSE_SECTIONS CS WITH (NOLOCK) ON SCS.SCS_COURSE_SECTION= CS.COURSE_SECTIONS_ID 
 WHERE  
   SACS.POS=1   

   --  college credit course 
    AND CS.SEC_ACAD_LEVEL='CC'    

--  CRED TYPE
 AND SAC.STC_CRED_TYPE  IN ('AR','C', 'CBE', 'D','MR','NFR','R')  
 
 -- with a positive number of units
 AND SAC.STC_CRED >0  
 
 -- FROM JULY OF PRIOR YEAR  
  AND CONVERT(VARCHAR(8),SAC.STC_START_DATE,112) >= @STC_START_DATE_LOWER_LIMIT  -- FROM JULY OF THE PRIOR YEAR 



  --select * from X1098T_TY21_STU_ENR
	-- The student residency qualify iif 
	-- a) the student residency is not A nor F
	-- or
	-- b) if student residency is A or F, then student is not missing SSN

  */

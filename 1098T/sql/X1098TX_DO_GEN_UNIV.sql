USE coll18_test1
set transaction isolation level read uncommitted

/***************************************************************************************************
 Name: X1098TX_DO_GEN_UNIV
 Purpose: Invokes X1098TX_GEN_UNIV to obtain list of students 
   that are the universe population for the 1098T workfile generation in Colleague.

 Maint log
 Ver    Date      Author      Description
 -----------------------------------------
 1.0   3/9/23    cschultz  
 Initial implementation.
 **************************************************************************************************/
 DECLARE @P_TAX_YEAR  VARCHAR(4)
 
 -- Set tax year as appropriate
 SET @P_TAX_YEAR  ='2022'

 -- execute script
 exec dbo.X1098TX_GEN_UNIV @P_TAX_YEAR

 -- result set is ouputted
 -- Get this to create a savedlist in Colleague,
 -- and provide the savedlist to the user.

 -- If want to inspect logs:
 SELECT * FROM X1098T_LOG ORDER BY LOG_ID DESC
 


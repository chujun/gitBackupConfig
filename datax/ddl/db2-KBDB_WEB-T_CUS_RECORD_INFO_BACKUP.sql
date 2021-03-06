CREATE TABLE "KBDB_WEB"."T_CUS_RECORD_INFO_BACKUP"  (
		  "ROW_ID" INTEGER NOT NULL , 
		  "CHANNEL" CHAR(2) NOT NULL WITH DEFAULT ' ' , 
		  "MCHNTCD" CHAR(15) NOT NULL WITH DEFAULT ' ' , 
		  "MCHNTNM" VARCHAR(50) NOT NULL WITH DEFAULT '' , 
		  "CUSTOM_TYPE" CHAR(2) NOT NULL WITH DEFAULT ' ' , 
		  "PAYER_MCHNT_ID" VARCHAR(30) NOT NULL WITH DEFAULT '' , 
		  "PAYER_MCHNT_NM" VARCHAR(50) NOT NULL WITH DEFAULT '' , 
		  "BUSI_PLAT_ID" VARCHAR(30) , 
		  "GZGJ_MCHNT_CODE" VARCHAR(30) , 
		  "CREATETM" TIMESTAMP NOT NULL WITH DEFAULT CURRENT TIMESTAMP , 
		  "UPDATETM" TIMESTAMP NOT NULL WITH DEFAULT CURRENT TIMESTAMP )   
		 IN "CFG_TBS" INDEX IN "IDX_TBS" ; 
ALTER TABLE "KBDB_WEB"."T_CUS_RECORD_INFO_BACKUP" 
	ADD PRIMARY KEY
		("ROW_ID");
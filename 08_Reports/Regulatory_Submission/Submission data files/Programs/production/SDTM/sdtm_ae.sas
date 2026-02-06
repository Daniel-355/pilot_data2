/**********************************************************************
 Program:    sdtm_ae.sas
 Purpose:    create a ae
 Author:     Daniel
 Date:       2026-01-03
**********************************************************************/


/*====================*/
/* include _setup.sas and /*open log*/  */
/*====================*/;
%let SETUP_PATH=%str(C:\Users\hed2\Downloads\Clinical_Trial_2025_DrugA_Phase3\08_Reports\Regulatory_Submission\Submission data files\_setup_sdtm.sas);
%include "&SETUP_PATH";

%let PGNAME=dm;
/*%open_log(&PGNAME);*/


%make_empty_dataset(metadatafile=&root/SDTM_METADATA.xlsx,dataset=AE);
%put &AEKEEPSTRING;
/*STUDYID DOMAIN USUBJID AESEQ AETERM AEDECOD AEBODSYS AESEV AESER AEACN AEREL AESTDTC AEENDTC AESTDY AEENDY*/


**** DERIVE THE MAJORITY OF SDTM AE VARIABLES;
options missing = '~';  /*Specifies the character to print for missing numeric values.*/
data ae;
  set EMPTY_AE  /*empty dataset*/
  raw.adverse;  /*original variables*/
    studyid = 'XYZ123';
    domain = 'AE';
    usubjid = left(uniqueid);
run;

/*proc contents data= source.adverse varnum; run;  */
/*proc contents data= EMPTY_AE varnum; run; /*three variables missing*/*/;
 
proc sort
  data=ae;
    by usubjid;
run;


/*merge ae and reference start in dm*/
data ae;
  merge ae(in=inae) sdtm.dm(keep=usubjid rfstdtc);
    by usubjid;

    if inae;

    %make_sdtm_dy(refdate=rfstdtc,date=aestdtc);   /*aestdtc- rfstdtc= AESTDY*/
    %make_sdtm_dy(refdate=rfstdtc,date=aeendtc); /*aeendtc- rfstdtc= AEenDY*/
run;
/*(in=in ) To identify which input data set contributed an observation during a SET, MERGE, or UPDATE.*/
/*proc contents data= ae varnum; run;  */


**** CREATE SEQ VARIABLE;
proc sort
  data=ae;
    by studyid usubjid aedecod aestdtc aeendtc;
run;

data ae;
  retain STUDYID DOMAIN USUBJID AESEQ AETERM AEDECOD AEBODSYS AESEV AESER AEACN AEREL AESTDTC
         AEENDTC AESTDY AEENDY;
  set ae(drop=aeseq);
    by studyid usubjid aedecod aestdtc aeendtc;

    if not (first.aeendtc and last.aeendtc) then
      put "WARN" "ING: key variables do not define an unique record. " usubjid=;   /*the above sort varibles are not unique*/

    retain aeseq;
    if first.usubjid then
      aeseq = 1;
    else
      aeseq = aeseq + 1;
		
    label aeseq = "Sequence Number";
run;


**** SORT AE ACCORDING TO METADATA AND SAVE PERMANENT DATASET;
%make_sort_order(metadatafile=&root/SDTM_METADATA.xlsx,dataset=AE);
%put &AESORTSTRING;
/*STUDYID  USUBJID  AEDECOD  AESTDTC*/

proc sort
  data=ae(keep = &AEKEEPSTRING)
  out=sdtm.ae;
    by &AESORTSTRING;
run;

proc contents data= sdtm.ae varnum;
run;

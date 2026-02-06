/**********************************************************************
 Program:    sdtm_lb.sas
 Purpose:    create a lb
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


**** CREATE EMPTY DM DATASET CALLED EMPTY_DM;
 
%make_empty_dataset(metadatafile=&root/SDTM_METADATA.xlsx,dataset=LB);
 

proc format;
  value visit_labs_month
    0=baseline
    1=3 months
    2=6 months;
  run;


data lb;
  set EMPTY_LB
      raw.labs; 

    studyid = 'XYZ123';
    domain = 'LB';
/*chracter*/ /*BESTw. is a numeric format that displays values using the most appropriate notation*/
/*did not report error when appending */
usubjid = left(uniqueid);
    lborres = left(put(nresult,best.)); 
	lborresu = left(colunits);
    lbornrlo = left(put(lownorm,best.));
    lbornrhi = left(put(highnorm,best.));
/*Always include a dollar sign ($) after the variable name in the INPUT statement if it's a character variable.*/
/*left is chracter and right is numeric*/
lbcat = labcat;
    lbtest = labtest;
    lbtestcd = labtest;

    **** create standardized results; 
/*	numeric*/
    lbstresc = lborres;
    lbstresn = nresult;
    lbstresu = lborresu;
    lbstnrlo = lownorm;
    lbstnrhi = highnorm;

/*	create a new variable lbnrind*/
    if lbstnrlo ne . and lbstresn ne . and 
       round(lbstresn,.0000001) < round(lbstnrlo,.0000001) then
      lbnrind = 'LOW';
    else if lbstnrhi ne . and lbstresn ne . and 
       round(lbstresn,.0000001) > round(lbstnrhi,.0000001) then
      lbnrind = 'HIGH';
    else if lbstnrhi ne . and lbstresn ne . then
      lbnrind = 'NORMAL';

    visitnum = month;
    visit = put(month,visit_labs_month.);

    if visit = 'baseline' then
      lbblfl = 'Y';
	else
	  lbblfl = ' ';
/*define baseline*/
    lbdtc = put(labdate,yymmdd10.);   /*2025-09-02*/
run;

 
proc sort
  data=lb;
    by usubjid;
run;


**** CREATE SDTM STUDYDAY VARIABLES;
/*create lbdy*/
data lb;
  merge lb(in=inlb) sdtm.dm(keep=usubjid rfstdtc);
    by usubjid;

    if inlb;

    %make_sdtm_dy(refdate=rfstdtc,date=lbdtc) 
run;


**** CREATE SEQ VARIABLE  ;
proc sort
  data=lb;
    by studyid usubjid lbtestcd visitnum;
run;


data lb;
  retain STUDYID DOMAIN USUBJID LBSEQ LBTESTCD LBTEST LBCAT LBORRES LBORRESU LBORNRLO LBORNRHI 
         LBSTRESC LBSTRESN LBSTRESU LBSTNRLO LBSTNRHI LBNRIND LBBLFL VISITNUM VISIT LBDTC LBDY;
  set lb(drop=lbseq);
    by studyid usubjid lbtestcd visitnum;  /*sort*/

    if not (first.visitnum and last.visitnum) then   /*if missing*/
      put "WARN" "ING: key variables do not define an unique record. " usubjid=;

    retain lbseq;
    if first.usubjid then
      lbseq = 1;
    else
      lbseq = lbseq + 1;
		
    label lbseq = "Sequence Number";
run;


**** SORT LB ACCORDING TO METADATA AND SAVE PERMANENT DATASET;
%make_sort_order(metadatafile=&root/SDTM_METADATA.xlsx,dataset=LB);

proc sort
  data=lb(keep = &LBKEEPSTRING)
  out=sdtm.lb;
    by &LBSORTSTRING;
run;

proc contents data= sdtm.lb varnum;
run;
/*most should be chracter */

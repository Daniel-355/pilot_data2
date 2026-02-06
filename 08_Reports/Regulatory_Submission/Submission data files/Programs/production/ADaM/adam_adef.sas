/**********************************************************************
 Program:    adam_adef.sas
 Purpose:    create a adef
 Author:     Daniel
 Date:       2026-01-03
**********************************************************************/


/*====================*/
/* include _setup.sas and /*open log*/  */
/*====================*/;
%let SETUP_PATH=%str(C:\Users\hed2\Downloads\Clinical_Trial_2025_DrugA_Phase3\08_Reports\Regulatory_Submission\Submission data files\_setup_adam.sas);
%include "&SETUP_PATH";

%let PGNAME=adsl;
/*%open_log(&PGNAME);*/


*---------------------------------------------------------------*;
* ADEF.sas creates the ADaM BDS-structured data set
* for efficacy data (ADEF), saved to the ADaM libref.
*---------------------------------------------------------------*;

**** CREATE EMPTY ADEF DATASET CALLED EMPTY_ADEF;
%let metadatafile=&root/adam_metadata.xlsx;

%make_empty_dataset(metadatafile=&metadatafile,dataset=ADEF)
%put &adefKEEPSTRING;
/*STUDYID USUBJID AGE AGEGR1N RANDDT AGEGR1 SEX SITEID TRTPN TRTP PARAMCD PARAM COUNTRY AVISIT AVISITN ABLFL XPSEQ VISITNUM ADT ADY AVAL AVALC BASE CHG CRIT1FL CRIT1 ITTFL*/


** calculate changes from baseline for all post-baseline visits;

%cfb(indata=sdtm.xp, outdata=adef, dayvar=xpdy, avalvar=   xpstresn);  /*is what is the primary outcome/measurement*/

proc sort
  data = adam.adsl
  (keep = usubjid siteid country age agegr1 agegr1n sex race randdt trt01p trt01pn ittfl)
  out = adsl;
    by usubjid;
      
data adef;
  merge adef (in = inadef) adsl (in = inadsl);  /*in both datasets*/
    by usubjid ;
    
        if not(inadsl and inadef) then
          put 'PROB' 'LEM: Missing subject?-- '   usubjid= inadef= inadsl= ;
        
        rename trt01p    = trtp   /*generally in adsl trt01p but other trtp, if only one period  */
               trt01pn   = trtpn

               xptest    = param    /*test*/
               xptestcd  = paramcd

               visit     = avisit
               xporres   = avalc    /*values*/
        ;               

        if inadsl and inadef;
        avisitn = input(put(visitnum, avisitn.), best.);
        
        %dtc2dt(xpdtc, refdt=randdt);   /*date in adam convert into numeric*/
        
        retain crit1 "Pain improvement from baseline of at least 2 points";

        RESPFL = put((.z <= chg <= -2), _0n1y.);         /*flag is effective: improve from baseline at 2 points*/

        if RESPFL='Y' then
          crit1fl = 'Y';
        else
          crit1fl = 'N';          
run;

** assign variable order and labels;
data adef;
  retain &ADEFKEEPSTRING;
  set EMPTY_ADEF adef;   /*put empty table first*/
  keep &ADEFKEEPSTRING;
run;

**** SORT ADEF ACCORDING TO METADATA AND SAVE PERMANENT DATASET;

%make_sort_order(metadatafile=&metadatafile,dataset=ADEF)

proc sort
  data=adef 
  out=adam.adef;
    by &ADEFSORTSTRING;
run;        

/*proc contents data=adam.adef varnum; run; */

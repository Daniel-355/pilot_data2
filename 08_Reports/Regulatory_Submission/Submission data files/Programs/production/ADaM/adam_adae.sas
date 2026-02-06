/**********************************************************************
 Program:    adam_adae.sas
 Purpose:    create a adae
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
* ADAE.sas creates the ADaM ADAE-structured data set
* for AE data (ADAE), saved to the ADaM libref.
*---------------------------------------------------------------*;

**** CREATE EMPTY ADAE DATASET CALLED EMPTY_ADAE;
%let metadatafile=&root/adam_metadata.xlsx;

%make_empty_dataset(metadatafile=&metadatafile,dataset=ADAE)
%put &adaeKEEPSTRING;
/*UDYID USUBJID SITEID COUNTRY AESEQ AGE AGEGR1N AGEGR1 SEX TRTAN TRTA AETERM AEDECOD AEBODSYS ASTDT SAFFL AENDT AESEV ASTDY AESEVN AENDY AESER AEACN AEREL AERELN CQ01NAM RELGR1 RELGR1N TRTEMFL*/


proc sort
  data = adam.adsl
  (keep = usubjid siteid country age agegr1 agegr1n sex race trtsdt trt01a trt01an saffl)
  out = adsl;
    by usubjid;

data adae;
  merge sdtm.ae (in = inae) adsl (in = inadsl);
    by usubjid ;   /*merge by usubjid*/
    
        if inae and not inadsl then
          put 'PROB' 'LEM: Subject missing from ADSL?-- ' usubjid= inae= inadsl= ;  /*ae not in adsl*/
        
/*		  another if */
        rename trt01a    = trta
               trt01an   = trtan
        ;               
        if inadsl and inae;
        
        %dtc2dt(aestdtc, prefix=ast, refdt=trtsdt);
        %dtc2dt(aeendtc, prefix=aen, refdt=trtsdt);

        if index(AEDECOD, 'PAIN')>0 or AEDECOD='HEADACHE' then
          CQ01NAM = 'PAIN EVENT';
        else
          CQ01NAM = '          '; 
/*          The customized query (CQ) name or name of the AE of special interest category based on a grouping of terms. Would be blank for terms that are not in the ...*/
        aereln = input(put(aerel, $aereln.), best.);  /*relate  , multiple categories*/
        aesevn = input(put(aesev, $aesevn.), best.); /*serious or not*/
        relgr1n = (aereln);       ** group related events (AERELN>0);
        relgr1  = put(relgr1n, relgr1n.);  /*relate or not*/

        if astdt>=trtsdt then
          trtemfl = 'Y';    /*treat emergency*/

        format astdt aendt yymmdd10.;
run;
/**/
/*proc freq data= sdtm.ae;*/
/*table aerel  aesev;*/
/*run; */

** assign variable order and labels;
data adae;
  retain &adaeKEEPSTRING;
  set EMPTY_adae adae;
run;

**** SORT adae ACCORDING TO METADATA AND SAVE PERMANENT DATASET;

%make_sort_order(metadatafile=&metadatafile, dataset=ADAE)

proc sort
  data=adae(keep = &adaeKEEPSTRING)
  out=adam.adae;
    by &adaeSORTSTRING;
run;        

/*proc contents data=adam.adae varnum; run; */

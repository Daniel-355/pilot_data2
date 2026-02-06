/**********************************************************************
 Program:    adam_adsl.sas
 Purpose:    create a adsl
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


*------------------------------------------------------------*;
* ADSL.sas creates the ADaM ADSL data set
* as permanent SAS datasets to the ADaM libref.
*------------------------------------------------------------*;

**** CREATE EMPTY ADSL DATASET CALLED EMPTY_ADSL;

%let metadatafile=&root/adam_metadata.xlsx;  /*create a local macro variable*/
 /*invoke a macro*/*/;
%make_empty_dataset(metadatafile=&metadatafile, dataset=ADSL) ;
%put &adslKEEPSTRING;


** merge supplemental qualifiers: RACEOTH RANDDT  into DM using sdtm.suppdm and sdtm.dm;
/*dm*/
%mergsupp(sourcelib=sdtm, domains=DM); 
/*based on a macro %macro mergsupp(sourcelib=library, outlib=WORK, domains= , suppqual=0);*/

** find the change from baseline so that responders can be flagged ;
** (2-point improvement in pain at 6 months);
/*responders*/
%cfb(indata=sdtm.xp, outdata=responders,    dayvar=xpdy,   avalvar= xpstresn, /*using sdtm.xp data- baseline*/
     keepvars=usubjid visitnum chg);
/*based on a macro %macro cfb(indata= ,outdata= ,avalvar=   numerical value ,dayvar= study day ,keepvars=  );*/
/*proc contents data=sdtm.xp varnum; run; */

/*	 convert the date variables*/
/*%include "&path2/dtc2dt.sas";*/
/*based on a macro %macro dtc2dt(dtcvar , prefix=a, refdt= );*/

data ADSL;
    merge EMPTY_ADSL
          	DM         (in = inDM) 
          	responders (in = inresp where=(visitnum=2))
/*			the above derived datasets*/
          	;
      by usubjid;

        * convert RFSTDTC to a numeric SAS date named TRTSDT;
        %dtc2dt(RFSTDTC, prefix=TRTS );  
        * create BRTHDT, RANDDT, TRTEDT;
        %dtc2dt(BRTHDTC, prefix=BRTH);        
        %dtc2dt(RANDDTC, prefix=RAND);
        %dtc2dt(RFENDTC, prefix=TRTE);

/*        * created flags for ITT and safety-evaluable;*/
        ittfl = put(randdt, popfl.);  /*popfl.  0 to high is yes*/
        saffl = put(trtsdt, popfl.);
/**/
        trt01p = ARM;
        trt01a = trt01p;
        trt01pn = input(put(trt01p, $trt01pn.), best.);
        trt01an = trt01pn;    
/* */
        agegr1n = input(put(age, agegr1n.), best.);  /*no need if else group,  category then numeric  */
        agegr1  = put(agegr1n, agegr1_.);   /*text*/

        RESPFL = put((.z   <= chg <= -2), _0n1y.);         /*text, where chg > .z is an efficient way to select only non-missing numeric values, 1 and 0*/
;
		run;
/*proc contents data=ADSL varnum; run; */
/*WARNING: Multiple lengths were specified for the variable SEX by input data set(s). This can*/
/*         cause truncation of data.*/


**** SORT ADSL ACCORDING TO METADATA AND SAVE PERMANENT DATASET;
%make_sort_order(metadatafile=&metadatafile, dataset=ADSL);
%put &ADSLSORTSTRING;
 %put &adslKEEPSTRING;
/*STUDYID USUBJID SUBJID RANDDT TRTSDT TRTEDT SITEID BRTHDT AGE AGEU AGEGR1 AGEGR1N SEX RACE*/
/*RACEOTH ARM TRT01P TRT01A TRT01PN TRT01AN COUNTRY ITTFL SAFFL RESPFL*/

proc sort
  data=adsl
  (keep = &ADSLKEEPSTRING)
  out=adam.adsl;
    by &ADSLSORTSTRING;
run;

proc contents data=adam.adsl varnum; run; 

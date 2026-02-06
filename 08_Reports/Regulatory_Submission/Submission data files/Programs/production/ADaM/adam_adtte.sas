/**********************************************************************
 Program:    adam_adtte.sas
 Purpose:    create a adtte
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
* ADTTE.sas creates the ADaM BDS-structured data set
* for a time-to-event analysis (ADTTE), saved to the ADaM libref.
*---------------------------------------------------------------*;

**** CREATE EMPTY ADTTE DATASET CALLED EMPTY_ADTTE;
%let metadatafile=&root/adam_metadata.xlsx;

%make_empty_dataset(metadatafile=&metadatafile, dataset=ADTTE)
/*%put &adtteKEEPSTRING;*/
/*STUDYID USUBJID AGE AGEGR1N AGEGR1 SEX SITEID TRTPN TRTP PARAMCD PARAM COUNTRY ADT AVAL STARTDT*/
/*CNSR EVNTDESC SRCDOM SRCVAR SRCSEQ ITTF*/


/*time to event based on the adsl*/
proc sort
  data = adam.adsl
  (keep = studyid usubjid siteid country age agegr1 agegr1n sex race randdt trt01p trt01pn   /*represent 01 period, after randomized */
          ittfl     trtedt)   /* trtedt , last time exposure */
  out = adtte;
    by usubjid;
    

proc sort
  data = adam.adef
  (keep = usubjid paramcd chg         adt visitnum xpseq)   /*adt , analysis time*/
  out = adef;
    where paramcd='XPPAIN' and visitnum>0 and (chg<0 or chg>0);  /*paramcd='XPPAIN' there are other parameters; 
	visitnum>0 not baseline; (chg<0 or chg>0) must have effect */
    by usubjid adt;
    
	** keep only the first occurence of a pain relieve event;
data adef;
  set adef;
    by usubjid adt;
    
        drop paramcd visitnum;
        if first.usubjid;
run;
           
/*keep censor*/
proc sort
  data = adam.adae
  (keep = usubjid cq01nam    astdt      trtemfl aeseq) /*trtemfl */
  out = adae;
    where cq01nam ne '' and trtemfl='Y';  /*to identify Adverse Events (AEs) that occurred or worsened during a treatment period.*/
    by usubjid astdt;
run;

** keep only the first occurence of a pain event;
data adae;
  set adae;
    by usubjid astdt;
    
        if first.usubjid;
run;        


** get the sequence number for the last EX record;
proc sort
  data = sdtm.ex
  (keep = usubjid exseq)
  out = lstex
  nodupkey;
    by usubjid exseq;

data lstex;
  set lstex;
    by usubjid exseq;
    	if last.usubjid;


/*merge the above datasets*/
data adtte;
  merge adtte (in = inadtte rename=(randdt=startdt))   /*random date is start time*/
        adef  (in = inadef) 
        adae  (in = inadae) 
        lstex (in = inlstex)
        ;
    by usubjid ;
    
        retain param "TIME TO FIRST PAIN RELIEF" paramcd "TTPNRELF";

        rename trt01p    = trtp
               trt01pn   = trtpn
        ;               

        length srcvar $10. srcdom $4.;    /*define length*/   

        if (.<chg<0) and (adt<astdt or not inadae) then     /*relief*/ /*astdt adverse event time more than analysis time*/
          do;
            cnsr = 0;
            adt  = adt;
            evntdesc = put(cnsr, evntdesc.) ;     /*evntdesc description*/
            srcdom = 'ADEF';
            srcvar = 'XPDY';
            srcseq = xpseq;
          end;
/*        value evntdesc 0 = 'PAIN RELIEF'*/
/*                       1 = 'PAIN WORSENING PRIOR TO RELIEF'*/
/*                       2 = 'PAIN ADVERSE EVENT PRIOR TO RELIEF'*/
/*                       3 = 'COMPLETED STUDY PRIOR TO RELIEF'*/
        else if chg>0 and (adt<astdt or not inadae) then /*worsen*/   /*astdt adverse event time more than analysis time*/
          do;
            cnsr = 1;
            adt  = adt;
            evntdesc = put(cnsr, evntdesc.) ;
            srcdom = 'XP';
            srcvar = 'XPDY';
            srcseq = xpseq;
          end;

        else if (.<astdt<adt) then /*astdt adverse event time less than analysis time*/
          do; 
            cnsr = 2;
            adt  = astdt;
            evntdesc = put(cnsr, evntdesc.) ;
            srcdom = 'ADAE';
            srcvar = 'ASTDY';
            srcseq = aeseq;
          end;

        else 
          do;
            cnsr = 3;    /*3 = 'COMPLETED STUDY PRIOR TO RELIEF'*/
            adt  = trtedt;
            evntdesc = put(cnsr, evntdesc.) ;
            srcdom = 'ADSL';
            srcvar = 'TRTEDT';
            srcseq = .;
          end;


        aval = adt - startdt + 1;   /*numeric time */  /*  analysis time- random time*/
        
        format startdt adt yymmdd10.;
run;


** assign variable order and labels;
data adtte;
  retain &adtteKEEPSTRING;
  set EMPTY_adtte adtte;
run;

**** SORT adtte ACCORDING TO METADATA AND SAVE PERMANENT DATASET;

%make_sort_order(metadatafile=&metadatafile, dataset=ADTTE)

proc sort
  data=adtte(keep = &adtteKEEPSTRING)
  out=adam.adtte;
    by &adtteSORTSTRING;
run;        


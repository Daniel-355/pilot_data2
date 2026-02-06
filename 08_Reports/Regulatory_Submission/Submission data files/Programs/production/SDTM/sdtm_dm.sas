/**********************************************************************
 Program:    sdtm_dm.sas
 Purpose:    create a dm
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


*---------------------------------------------------------------*;
* STDM_DM.sas creates the SDTM DM and SUPPDM datasets and saves them
* as permanent SAS datasets to the target libref.
*---------------------------------------------------------------*;

/*%common;*/
/*set file path*/

**** CREATE EMPTY DM DATASET CALLED EMPTY_DM from metadata;
%make_empty_dataset(metadatafile=&root/SDTM_METADATA.xlsx,dataset=DM);
%put &DMkeepSTRING;
/*include metadata variables types formats code labels */


/*process dosing dataset*/
**** GET FIRST AND LAST DOSE DATE FOR RFSTDTC AND RFENDTC;
proc sort
  data=raw.dosing(keep=subject startdt enddt)
  out=dosing;
    by subject startdt;
run;

**** FIRSTDOSE=FIRST DOSING AND LASTDOSE=LAST DOSING for each person ???;
/*create first and last date for each person*/
data dosing;
  set dosing;
    by subject;
    format firstdose lastdose mmddyy10.;
    retain firstdose lastdose;

    if first.subject then
      do;
        firstdose = .;
        lastdose = .;
      end;

    firstdose = min(firstdose,startdt,enddt);
    lastdose = max(lastdose,startdt,enddt);

    drop startdt enddt;
    if last.subject;
run; 


**** GET DEMOGRAPHICS DATA;
proc sort
  data=raw.demographic
  out=demographic;
    by subject;
run;

/*merge demographics data and dosing data*/
data demog_dose;
  merge demographic
        dosing;
    by subject;
run;


**** DERIVE THE MAJORITY OF SDTM DM VARIABLES;
/*create new variables and append with empty table  */
data dm;
  set EMPTY_DM            /*empty dm*/
    demog_dose;       
/*by same rank*/
    studyid = 'XYZ123';
    domain = 'DM';

    usubjid = left(uniqueid);
    subjid = put(subject,3.); 
    rfstdtc = put(firstdose,yymmdd10.);  
    rfendtc = put(lastdose,yymmdd10.); 
    siteid = substr(subjid,1,1) || "00";
    brthdtc = put(dob,yymmdd10.);
    age = floor ((intck('month',dob,firstdose) - 
          (day(firstdose) < day(dob))) / 12);  /*create age using floor*/

    if age ne . then
        ageu = 'YEARS';

    country = "USA";
    sex=gender;
    arm=trt1;
    armcd=put(trt,3.);

    drop gender trt trt1;
run;
/*It is crucial to ensure that the underlying data type (numeric or character) of the variable is consistent across the datasets being merged.*/
/*proc contents data= EMPTY_DM varnum;run;*/
/*proc contents data=  DM varnum;run;     /*using the format from empty_dm*/*/;


/*keep variables and sort using macro variables from metadata*/

%make_sort_order(metadatafile=&root/SDTM_METADATA.xlsx,dataset=DM);
%put &DMSORTSTRING;
/*STUDYID  USUBJID ???*/

/*create final dm*/
proc sort
  data=dm(keep = &DMKEEPSTRING)
  out=sdtm.dm ;
    by &DMSORTSTRING;
run;



**** CREATE EMPTY SUPPDM DATASET              CALLED EMPTY_DM; 
%make_empty_dataset(metadatafile=&root/SDTM_METADATA.xlsx,dataset=SUPPDM);
%put &SUPPDMKEEPSTRING;  /*keep string*/
/*STUDYID RDOMAIN USUBJID IDVAR IDVARVAL QNAM QLABEL QVAL QORIG QEVAL*/

data suppdm;
  set EMPTY_SUPPDM
      dm; 

    keep &SUPPDMKEEPSTRING;  /*select variables */

    **** OUTPUT OTHER RACE AS A SUPPDM VALUE;    
/*generate records by condition clause*/
    if orace ne '' then
      do;
        rdomain = 'DM';
        qnam = 'RACEOTH';                /*long format data*/
        qlabel = 'Race, Other';
        qval = left(orace);
        qorig = 'CRF';
        output;
      end;

    **** OUTPUT RANDOMIZATION DATE AS SUPPDM VALUE;
    if randdt ne . then
      do;
        rdomain = 'DM';
        qnam = 'RANDDTC'; 
        qlabel = 'Randomization Date';
        qval = left(put(randdt,yymmdd10.));
        qorig = 'CRF';
        output;
      end;
run;

/*sort variables according to the metadata table*/
%make_sort_order(metadatafile=&root/SDTM_METADATA.xlsx,dataset=SUPPDM);
%put &SUPPDMSORTSTRING;   /*sort string*/
proc sort
  data=suppdm
  out=sdtm.suppdm;
    by &SUPPDMSORTSTRING;
run;

proc contents data= sdtm.suppdm varnum;
run;
proc contents data= sdtm.dm varnum;
run;

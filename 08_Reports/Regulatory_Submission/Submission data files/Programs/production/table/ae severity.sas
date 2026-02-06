/**********************************************************************
 Program:    ae_sev.sas
 Purpose:    create a ae sev
 Author:     Daniel
 Date:       2026-01-03
**********************************************************************/


/*====================*/
/* include _setup.sas and /*open log*/  */
/*====================*/;
%let SETUP_PATH=%str(C:\Users\hed2\Downloads\Clinical_Trial_2025_DrugA_Phase3\08_Reports\Regulatory_Submission\Submission data files\_setup.sas);
%include "&SETUP_PATH";

%let PGNAME=dm_chracters;
/*%open_log(&PGNAME);*/

/*=========================================================
set Input and output 
=========================================================*/
%let PROGDIR  = &ROOT.\Programs\production\table\;
%let outputpath= &ROOT.\Outputs\table;

/*=========================================================
Programming for the Task
=========================================================*/
 
/*=========================================================
Read input datasets
=========================================================*/
 
data adsl01;
   set adam.adsl;
   where saffl="Y";
run;
 
data adae01;
   set adam.adae;
   where saffl="Y" and trtemfl="Y";  /*safty and teae (Treatment Emergent Adverse Event) From the time of the first dose,
until the end of the prescribed safety follow-up period after the last dose.*/
run;
 
 
/*=========================================================
Create a numeric variable for AE severity
=========================================================*/
data adae02;
   set adae01;
   if upcase(aesev)="MILD" then asevn=1;
   else if upcase(aesev)="MODERATE" then asevn=2;
   else if upcase(aesev)="SEVERE" then asevn=3;
run;
 
 
/*=========================================================
Macro for ---------flagging first occurences - by subject, by soc in subject, by pt in subject
=========================================================*/
 
%macro anyflag(flag=,where=%str(trtemfl="Y"),byvar=,first=);
 
data adae1;
   set adae02;
   if &where then output adae1;
run;
 
proc sort data=adae1;
   by &byvar. aeseq;
run;
 
data adae1;
   set adae1;
   by &byvar. aeseq;
   if last.&first.;
   keep &byvar. aeseq;
run;
 
proc sort data=adae02;
   by &byvar. aeseq;
run;
 
data adae02;
   merge adae02(in=a) adae1(in=b);
   by &byvar. aeseq;
   if a and b then &flag="Y";
run;
 
%mend;
 
/*=========================================================
Call the macro to create occurrence flags at subject, soc and pt level on maximum severity  
 use dataset adae02
=========================================================*/
 
%anyflag(flag=aoccifl,byvar=usubjid asevn,first=usubjid);   /*by subject by severity*/
%anyflag(flag=aoccsifl,byvar=usubjid aebodsys asevn ,first=aebodsys);  /*by subject by system by severity*/
 
%anyflag(flag=aoccpifl,byvar=usubjid aebodsys aedecod asevn ,first=aedecod);  /*by subject by deocode by severity*/
 
 
/*=========================================================
Create variable named 'treatment' to hold report level column groupings
=========================================================*/
 
data adsl02;
   set adsl01;
   treatment=trt01an;
   output;
   treatment=99;
   output;
run;
 
data adae03;
   set adae02;
   treatment=trtan;
   output;
   treatment=99;
   output;/*output twice here*/
run;

/*=========================================================
Duplicate the rows to populate -----'Total' severity level
=========================================================*/
 
data adae04;
   set adae03;
   output;
   asevn=100;   /*1 2 3 for severity three levels but 100 for total of the three levels*/
   output;   
run;

/*=========================================================
Get treatment totals into a dataset and into macro variables(for column headers)
=========================================================*/
 
/*----------------------------------------------------------
Get treatment totals based on actual data -------demoninator
----------------------------------------------------------*/
proc sql;
   create table trttotals_pre as
      select treatment,
      count(distinct usubjid) as trttotal
      from adsl02
      group by treatment;
quit;
 
 
/*----------------------------------------------------------
Create dummy dataset to hold all treatment levels
----------------------------------------------------------*/
data dummy_trttotals;
   do treatment=0,54,81,99;
      output;
   end;
run;
 
 
/*----------------------------------------------------------
Merge actual counts with dummt counts
----------------------------------------------------------*/
 
data trttotals;
   merge dummy_trttotals(in=a) trttotals_pre(in=b);
   by treatment;
   if trttotal=. then trttotal=0;
run;
 
 
/*----------------------------------------------------------
Create macro variables
----------------------------------------------------------*/
 
data _null_;
    set trttotals;
    call symputx(cats("n",treatment),trttotal);
run;
 
 
/*=========================================================
Obtaining actual counts-for the table
three first occurence ae by three kinds of levels
--------calculate nominator
=========================================================*/
 
/*----------------------------------------------------------
Subject level count- top row
----------------------------------------------------------*/
 
proc sql noprint;
   create table sub_count as
   select "Overall" as label length=200,     asevn,treatment,
   "" as aebodsys length=120,       "" as aedecod length=120,     /*no label*/
   count(distinct usubjid) as subjects     /*calculate the unique counts*/

   from adae04

   where aoccifl="Y"      /*by subject*/
   group by asevn,  treatment; /*by severity by treatment */
quit;
 
 
/*----------------------------------------------------------
SOC level counts
----------------------------------------------------------*/
 
proc sql;
   create table soc_count as
      select aebodsys, asevn,treatment,
      count(distinct usubjid) as subjects
      from adae04

      where aoccsifl="Y"
      group by aebodsys,asevn,treatment;
quit;
 
 
/*----------------------------------------------------------
Preferred term level counts
----------------------------------------------------------*/
proc sql noprint;
   create table pt_count as
      select aebodsys,aedecod,asevn,treatment,
      count(distinct usubjid) as subjects
      from adae04

      where aoccpifl="Y"
      group by aebodsys,aedecod,asevn,treatment;
quit;
 

/*----------------------------------------------------------
---------Put all counts together
----------------------------------------------------------*/
 
data counts01;
   set sub_count soc_count pt_count;    /*append directly*/
run;
 
/*=========================================================
Create zero counts if an event is not present in a trt
=========================================================*/
 
/*----------------------------------------------------------
Get all the available soc-s and pt-s
----------------------------------------------------------*/
 
proc sort data=counts01 out=dummy01(keep=aebodsys aedecod label) nodupkey;    /*deduplicate, then create a empty table*/
   by aebodsys aedecod label;
run;
 
/*----------------------------------------------------------
Create a row for each treatment and severity level
----------------------------------------------------------*/
 data dummy02;
   set dummy01;
   do treatment=0,54,81,99;
      do asevn=1,2,3,100;
         output;
      end;
   end;
run;
 
 
/*=========================================================
Merge dummy counts with actual counts , --------in order to all zero cell 
=========================================================*/
proc sort data=dummy02;
   by aebodsys aedecod label asevn treatment;
run;
 
proc sort data=counts01 ;
   by aebodsys aedecod label asevn treatment;
run;
 
data counts02;
   merge dummy02(in=a) counts01(in=b);
   by aebodsys aedecod label asevn treatment;
   if subjects=. then subjects=0;
run;
 
 
/*=========================================================
Calculate percentages
=========================================================*/
 
/*----------------------------------------------------------
Merge counts with trttotals dataset, to get denominator values(trt totals)
----------------------------------------------------------*/
 
proc sort data=counts02;
   by treatment;
run;
 
proc sort data=trttotals;
   by treatment;
run;
 
data counts03;
   merge counts02(in=a) trttotals(in=b);
   by treatment;
   if a;
run;
 
data counts04;
   set counts03;
   length cp $30;
   if subjects ne 0 then cp=put(subjects,3.)||" ("||put(subjects/trttotal*100,5.1)||"%)";    /*calculate percentage, cp */
   else cp=put(subjects,3.);
run;
 
 
/*=========================================================
Create the --------label column
=========================================================*/
 
data counts05;
   set counts04;
   if missing(aebodsys) and missing(aedecod) then label=label;
   else if not missing(aebodsys) and missing(aedecod) then label=strip(aebodsys);
   else if not missing(aebodsys) and not missing(aedecod) then label='(*ESC*)R"\pnhang\fi220\li220 "'||strip(aedecod);
run;
 
/*=========================================================
Transpose to obtain treatment as columns
=========================================================*/
 
proc sort data=counts05;
   by aebodsys aedecod asevn label ;   /*sort for transpose */
run;
 
proc transpose data=counts05 out=trans01 prefix=trt;
   by aebodsys aedecod asevn label;
   var cp;
   id treatment;
run;
 
 
/*=========================================================
Create descriptive ----------label for severity column
=========================================================*/
 
data trans02;
   set trans01;
   length severity $20;
   if asevn=1 then severity="Mild";
   else if asevn=2 then severity="Moderate";
   else if asevn=3 then severity="Severe";
   else if asevn=100 then severity="Total";
   keep aebodsys aedecod asevn label trt0 trt54 trt81 trt99 label severity;
run;
 
proc sort data=trans02;
   by aebodsys aedecod label asevn;
run;
 
 
/*=========================================================
-------------report generation
=========================================================*/
 
%rtf_output_style_setup(
  protocol=XXX01,
  population=%str(Safety Analysis Set),
  pgm_path=%str(C:\XXX01\PROGRAMS\DRAFT\TFLs\ZZZ.sas)
); 


title3 "^S={foreground=blue fontweight=bold fontstyle=italic}Treatment-Emergent Adverse Events by Maximum Severity";
title4 "^S={foreground=blue fontweight=bold fontstyle=italic}Safety Analysis Set";


ods listing close;
options orientation=landscape nodate nonumber nobyline;

ods rtf file="&outputpath.\ae_severity.rtf"  style=csgpool01;
 
proc report data=trans02 nowd headline headskip missing style(report)=[just=center]
   style(header)=[just=center];
   columns aebodsys aedecod  label  asevn severity trt0 trt54 trt81;
   define aebodsys/ order noprint order=data;
   define aedecod/order noprint order=data;
   define asevn /order noprint order=data;
   define label /order "System Organ Class" '(*ESC*)R"\fi-420\li420 "Preferred Term' style(column)=[cellwidth=3.7in protectspecialchars=off]
            style(header)=[just=left];
   define severity/"Maximum" "Severity" style(column)=[cellwidth=.8in just=Left] style(header)=[just=left];
   define trt0/"Placebo" "(N=%cmpres(&n0))" "   n  (%)" style(column)=[cellwidth=1.2in just=center] ;
   define trt54/"Low Dose" "(N=%cmpres(&n54))" "   n  (%)" style(column)=[cellwidth=1.2in just=center]   ;
   define trt81/"High Dose" "(N=%cmpres(&n81))" "   n  (%)" style(column)=[cellwidth=1.2in just=center]   ;
 
   compute after aedecod;
      line @1 "";
   endcomp;
 
run;
 
ods rtf close;


/*This is the default/standard capability of ODS RTF, but only if you are using the headers from PROC REPORT, PROC TABULATE, or PROC PRINT.*/

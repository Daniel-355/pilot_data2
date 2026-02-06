/**********************************************************************
 Program:    ae_relationship.sas
 Purpose:    create a ae rel
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
   where saffl="Y" and trtemfl="Y";
run;
 
 
/*=========================================================
````````````Create a numeric variable for AE relationship
=========================================================*/
data adae02;
   set adae01;
   if upcase(aerel)="NONE" then areln=1;
   else if upcase(aerel)="REMOTE" then areln=2;
   else if upcase(aerel)="POSSIBLE" then areln=3;
   else if upcase(aerel)="PROBABLE" then areln=4;
   else if aerel="" then areln=99;
run;
 
 
/*=========================================================
Macro for flagging first occurences
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
   by &byvar.;
   if a and b then &flag="Y";
run;
 
%mend;
 
/*=========================================================
````````````Call the macro to create occurrence flags at subject, soc and pt level on maximum relationship
=========================================================*/
 
%anyflag(flag=aoccifl,byvar=usubjid areln,first=usubjid);
%anyflag(flag=aoccsifl,byvar=usubjid aebodsys areln ,first=aebodsys);
%anyflag(flag=aoccpifl,byvar=usubjid aebodsys aedecod areln ,first=aedecod);
 
 
/*=========================================================
Create variable named 'treatment' to hold report level column groupings
=========================================================*/
/* no total in this table */
data adae03;
   set adae02;
   treatment=trtan;
   output;
run;
 
data adsl02;
   set adsl01;
   treatment=trt01an;
   output;
run;
 
/*=========================================================
```````````Duplicate the rows to populate 'Total' relationship level
=========================================================*/
 
data adae04;
   set adae03;
   output;

   areln=100;   /*1 2 3 4 100=overall*/
   output;
run;
 
/*=========================================================
`````````````Get treatment totals into a dataset and into macro variables(for column headers)
=========================================================*/
 
/*----------------------------------------------------------
Get treatment totals based on actual data
----------------------------------------------------------*/
proc sql;
   create table trttotal_pre as
      select treatment,
      count(distinct usubjid) as trttotal
      from adsl02
      group by treatment;
quit;
 
 
/*----------------------------------------------------------
Create dummy dataset to hold all treatment levels
----------------------------------------------------------*/
data dummy_pre;
   do treatment=0,54,81;
      output;
   end;
run;
 
 
/*----------------------------------------------------------
Merge actual counts with dummt counts
----------------------------------------------------------*/
 
data trttotals;
   merge dummy_pre(in=a) trttotal_pre(in=b);
   by treatment;
   if trttotal=. then trttotal=0;
run;
 
 
/*----------------------------------------------------------
Create macro variables (using sql)
----------------------------------------------------------*/
 
proc sql noprint;
   select count(distinct usubjid) into :n0 from adsl02 where treatment=0;
   select count(distinct usubjid) into :n54 from adsl02 where treatment=54;
   select count(distinct usubjid) into :n81 from adsl02 where treatment=81;
quit;
 
 
/*=========================================================
``````````````Obtaining actual counts-for the table
=========================================================*/
 
/*----------------------------------------------------------
Subject level count- top row
----------------------------------------------------------*/
 
proc sql noprint;
   create table sub_count as
   select "Overall" as label length=200,areln,treatment,
   "" as aebodsys length=120, "" as aedecod length=120,
   count(distinct usubjid) as subjects
   from adae04
   where aoccifl="Y"
   group by areln,treatment;
quit;
 
 
/*----------------------------------------------------------
SOC level counts
----------------------------------------------------------*/
 
proc sql;
   create table soc_count as
      select aebodsys, areln,treatment,
      count(distinct usubjid) as subjects
      from adae04
      where aoccsifl="Y"
      group by aebodsys,areln,treatment;
quit;
 
 
/*----------------------------------------------------------
Preferred term level counts
----------------------------------------------------------*/
proc sql noprint;
   create table pt_count as
      select aebodsys,aedecod,areln,treatment,
      count(distinct usubjid) as subjects
      from adae04
      where aoccpifl="Y"
      group by aebodsys,aedecod,areln,treatment;
quit;
 
/*----------------------------------------------------------
Put all counts together
----------------------------------------------------------*/
 
data counts01;
   set sub_count soc_count pt_count;
run;
 
/*=========================================================
Create zero counts if an event is not present in a trt
=========================================================*/
 
/*----------------------------------------------------------
Get all the available soc-s and pt-s
----------------------------------------------------------*/
 
proc sort data=counts01 out=dummy01(keep=aebodsys aedecod label) nodupkey;
   by aebodsys aedecod label;
run;
 
 
/*----------------------------------------------------------
Create a row for each treatment and relationship level
----------------------------------------------------------*/
 
data dummy02;
   set dummy01;
   do treatment=0,54,81;
      do areln=1,2,3,4,99,100;
         output;
      end;
   end;
run;
 
 
/*=========================================================
Merge dummy counts with actual counts
=========================================================*/
proc sort data=dummy02;
   by aebodsys aedecod label areln treatment;
run;
 
proc sort data=counts01 ;
   by aebodsys aedecod label areln treatment;
run;
 
data counts02;
   merge dummy02(in=a) counts01(in=b);
   by aebodsys aedecod label areln treatment;
   if subjects=. then subjects=0;
run;
 
 
/*=========================================================
`````````````````Obtain percentages
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
   if subjects ne 0 then cp=put(subjects,3.)||" ("||put(subjects/trttotal*100,5.1)||"%)";
   else cp=put(subjects,3.);
run;
 
 
/*=========================================================
Create the label column
=========================================================*/
 
data counts05;
   set counts04;
   if missing(aebodsys) and missing(aedecod) then label=label;
   else if not missing(aebodsys) and missing(aedecod) then label=strip(aebodsys);
   else if not missing(aebodsys) and not missing(aedecod) then label='(*ESC*)R"\pnhang\fi220\li220 "'||strip(aedecod);
run;
 
/*=========================================================
````````````Transpose to obtain treatment as columns
=========================================================*/
 
proc sort data=counts05;
   by aebodsys aedecod areln label ;
run;
 
proc transpose data=counts05 out=trans01 prefix=trt;
   by aebodsys aedecod areln label;
   var cp;
   id treatment;
run;
 
 
/*=========================================================
Create descriptive label for relationship column
=========================================================*/
 
data trans02;
   set trans01;
   length relationship $20;
   if areln=1 then relationship="None";
   else if areln=2 then relationship="Unlikely";
   else if areln=3 then relationship="Possible";
   else if areln=4 then relationship="Probable";
   else if areln=99 then relationship="Missing";
   else if areln=100 then relationship="Total";
   label;
   keep aebodsys aedecod areln label trt0 trt54 trt81 relationship;
run;
 
proc sort data=trans02;
   by aebodsys aedecod label areln;
run;
 
 
/*=========================================================
```````````report generation
=========================================================*/
 
 
%rtf_output_style_setup(
  protocol=XXX01,
  population=%str(Safety Analysis Set),
  pgm_path=%str(C:\XXX01\PROGRAMS\DRAFT\TFLs\ZZZ.sas)
); 
 

title3 "^S={foreground=blue fontweight=bold fontstyle=italic}Treatment-Emergent Adverse Events by Relationship to Study Drug";
title4 "^S={foreground=blue fontweight=bold fontstyle=italic}Safety Analysis Set";

ods listing close;
options orientation=landscape nodate nonumber nobyline;

ods rtf file="&outputpath.\ae_relationship.rtf" style=csgpool01;
 
proc report data=trans02 nowd headline headskip missing style(report)=[just=center]
   style(header)=[just=center];
   columns aebodsys aedecod  label  areln relationship trt0 trt54 trt81;
   define aebodsys/ order noprint order=data;
   define aedecod/order noprint order=data;
   define areln /order noprint order=data;
   define label /order "System Organ Class" '(*ESC*)R"\fi-420\li420 "Preferred Term' style(column)=[cellwidth=3.7in protectspecialchars=off]
            style(header)=[just=left];
   define relationship/"Maximum" "Relationship" style(column)=[cellwidth=.8in just=Left] style(header)=[just=left];
   define trt0/"Placebo" "(N=%cmpres(&n0))" "   n  (%)" style(column)=[cellwidth=1.2in just=center] ;
   define trt54/"Low Dose" "(N=%cmpres(&n54))" "   n  (%)" style(column)=[cellwidth=1.2in just=center]   ;
   define trt81/"High Dose" "(N=%cmpres(&n81))" "   n  (%)" style(column)=[cellwidth=1.2in just=center]   ;
 
   compute after aedecod;
      line @1 "";
   endcomp;
 
run;
 
ods rtf close;
 
/*%convert_rtf_to_pdf_vbscript;*/


/*Example: TEAE =5% Table*/
/**/
/*The analysis criteria for this table are:*/
/**/
/*Population: Safety population*/
/**/
/*Time window: First dose ? Last dose + 30 days*/
/**/
/*Definition: Any TEAE*/
/**/
/*Display rule: Incidence =5% in any treatment group*/
/**/
/*Method: n (%) by treatment*/
/**/
/* These five points together constitute "one set of analysis criteria".*/

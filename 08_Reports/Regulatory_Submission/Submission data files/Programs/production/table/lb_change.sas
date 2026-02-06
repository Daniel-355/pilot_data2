/**********************************************************************
 Program:    lab_change.sas
 Purpose:    create a lab change table
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
run;
/*  proc freq data=adsl;*/
/* table treatmentn; run; */
/* proc contents data=adsl varnum;run; */

data adlb01;
   set adam.adlbh;
   where saffl="Y" and anl01fl="Y" ;     /*`````````````anl01fl is Analysis Record Flag 1, is post baseline   */
run;
/*  proc contents data=adsl01 varnum;run; */
/* proc contents data=adlb01 varnum;run; */
/*=========================================================
Duplicate rows based on table column requirements
=========================================================*/
/*----------------------------------------------------------
First Column: RTRIPLFL="Y"
----------------------------------------------------------*/
/*----------------------------------------------------------
Second Column: All saffl="Y"
----------------------------------------------------------*/
data adsl02;
   set adsl01;
   if COMP24FL="Y" then do;
      treatment=1;                     /*`````````````two populations, complete 24 week and safety*/
      output;
   end;
   if saffl="Y" then do;
      treatment=2;
      output;
   end;
run;
/*   proc freq data=adlb01;*/
/* table avisitn; run; */

data adlb02;
   set adlb01;
   if COMP24FL="Y" then do;
      treatment=1;
      output;
   end;
   if saffl="Y" then do;
      treatment=2;
      output;
   end;
run;
/* rtriplfl*/
/*=========================================================
Choose the number of base decimals for each parameter
=========================================================*/
/*----------------------------------------------------------
This variable can be used to build formats dynamically for various statistics during character conversion
----------------------------------------------------------*/
 
data adlb03;
   set adlb02;
   if paramcd="MONO" then decimals=0;
   else if paramcd="PLAT" then decimals=2;      /*`````````````select two parameters codes*/
run;
 
/* proc freq data=adlbh ;*/
/* table paramcd;*/
/* run;*/


/*=========================================================
Create a single column to hold analysis value of interest: BASE, AVAL and CHG
=========================================================*/
 
data adlb04;
   set adlb03;
   valorder=1;
   result=base;
   output;

   valorder=2;
   result=aval;
   output;

   valorder=3;
   result=chg;               /*``````````stack three stats, baseline, post baseline, and change */
   output;
run;
 
 
/*=========================================================
Obtain descriptive statistics and process the data to get the table presentation format
=========================================================*/
 
/*----------------------------------------------------------
Sort the dataset based on required logic grouping
----------------------------------------------------------*/
 
proc sort data=adlb04;
   by paramn paramcd param decimals avisitn avisit valorder;
run;
 
/*----------------------------------------------------------
Obtain descriptive statistics using proc summary
----------------------------------------------------------*/
/*----------------------------------------------------------
``````````````````````Notice the usage of class statement <br/>
``````````````````````Notice the usage of nway option
----------------------------------------------------------*/
 
proc summary data=adlb04 nway ;
   class paramn paramcd param  /*parameters*/    decimals  /*parameters*/     avisitn avisit   /*visit times*/    treatment    /*populations*/   valorder  /*base, post, and change*/ ; 
   var result;
   output out=stat01 n=n mean=mean std=std median=median min=min max=max;
run;
/* proc contents data=adlb04 varnum;run; */
/**/
/*nway ? tells SAS to only output rows that have all CLASS variables present (no “ALL” rows).*/


/*----------------------------------------------------------
`````````````````````Build the formats based on number of base decimals
----------------------------------------------------------*/
/*----------------------------------------------------------
Notice the usage of addition of +1 and +2 to decimals while creating format<br/>

Notice the usage of exponentiation to create rounding rule
----------------------------------------------------------*/
data stat02;
   set stat01;
   length asisfmt plusonefmt plustwofmt $10;
   integers=8;*assuming that no test takes value more than 8 integers;
   if decimals=. then decimals=0;
 
   integers=integers+1;*to handle minus sign;
   asisfmt=cats(integers+1+decimals,".",decimals);
   plusonefmt=cats(integers+1+decimals+1,".",decimals+1);
   plustwofmt=cats(integers+1+decimals+2,".",decimals+2);
 
   asisround=10**(-1*decimals);
   plusoneround=10**(-1*(decimals+1));
   plustworound=10**(-1*(decimals+2));
run;
 
/*----------------------------------------------------------
Convert the statistics to character format and concatenate individual stats as per presentation requirement
----------------------------------------------------------*/
 
data stat03;
   set stat02;
   length _n _mean _std _median _min _max _meansd _minmax $50;
   if not missing(n) then _n=put(n,3.);
   else _n=put(0,3.);
 
   *asis stats;
   if not missing(min) then _min=putn(round(min,asisround),asisfmt);
   if not missing(max) then _max=putn(round(max,asisround),asisfmt);
 
   *plusone stats;
   if not missing(mean) then _mean=putn(round(mean,plusoneround),plusonefmt);
   if not missing(median) then _median=putn(round(median,plusoneround),plusonefmt);
 
   *plustwo stats;
   if not missing(std) then _std=putn(round(std,plustworound),plustwofmt);
 
   *concatenating stats;
   if not missing(_mean) and not missing(_std) then _meansd=trim(_mean)||" ("||strip(_std)||")";             /*concatenate*/
   if not missing(_min) and not missing(_max) then _minmax=trim(_min)||" , "||strip(_max);
run;
 
 
/*----------------------------------------------------------
Transpose the stats to get them as rows for order 
----------------------------------------------------------*/
 
proc sort data=stat03;
   by paramn paramcd param avisitn avisit treatment valorder;
run;
 
proc transpose data=stat03 out=stat04;
   by paramn paramcd param avisitn avisit treatment valorder;
   var _n _meansd _median _minmax;
   label _n="n" _meansd="Mean (SD)" _median="Median" _minmax="Min , Max";
run;
 
/*----------------------------------------------------------
Create numeric variable to ```````````hold stat order
----------------------------------------------------------*/
 
data stat05;
   set stat04;
   length statistic $200;
   statistic=_label_;
   select(statistic);
      when ("n")  statorder=1;
      when ("Mean (SD)")  statorder=2;
      when ("Median")  statorder=3;
      when ("Min , Max")  statorder=4;
      otherwise;
   end;
run;
 
/*----------------------------------------------------------
Transpose the data again to get the valorder(within each treatment) as columns
----------------------------------------------------------*/
 
proc sort data=stat05;
   by paramn paramcd param avisitn avisit  statorder statistic treatment valorder;
run;
 
proc transpose data=stat05 out=stat06 prefix=trt_;
   by paramn paramcd param avisitn avisit statorder statistic;
   id treatment valorder;
   var col1;
run;
 
 
/*=========================================================
``````````````````Process the data for reporting layout and generate report
=========================================================*/
 
/*----------------------------------------------------------
Create page numbering variable such that statistics groups dont break in ``````````between
----------------------------------------------------------*/
 
data stat07;
   set stat06;
   by paramn paramcd param avisitn avisit statorder statistic;
 
   *count the number of visits;
 
   if first.avisit then nvisits+1;
 
   *increment the page by one for each 5th visit;
 
   if mod(nvisits,4)=1 and first.avisit then page+1;         /*use mod function */
run;
 
 
/*----------------------------------------------------------
Create additional for row each parameter to display once as a separate row
----------------------------------------------------------*/
 
proc sort data=stat07 out=paramlabels01 nodupkey;
   by paramn paramcd param;
run;
 
data paramlabels02;
   set paramlabels01;
   statorder=0;

   length statistic $200;
   statistic=param;
   keep paramn paramcd param statorder statistic page;
run;
 
/*----------------------------------------------------------
Create additional row for each visit within a parameter to display once as a separate row
----------------------------------------------------------*/
 
proc sort data=stat07 out=visitlabels01 nodupkey;
   by paramn paramcd param avisitn avisit;
run;
 
data visitlabels02;
   set visitlabels01;
   statorder=0;
   length statistic $200;
   statistic=avisit;
   keep paramn paramcd param avisitn avisit statorder statistic page;
run;
 
/*----------------------------------------------------------
`````````````Combine param and param-visit row labels to statistics dataset
----------------------------------------------------------*/
 
data stat08;
   set stat07(in=a) paramlabels02 visitlabels02;
   dummy="";
   if a then statistic="(*ESC*)R'\li120'"||strip(statistic);    /*(*ESC*)R tells SAS to insert raw RTF code.  it means “left indent by 120 twips”. 6 points (about 0.08 inch).*/
run;
/* strip( Removes leading/trailing spaces from the variable statistic.*/
/*----------------------------------------------------------
Sort the dataset as per final requirement
----------------------------------------------------------*/
proc sort data=stat08;
   by paramn paramcd param avisitn avisit statorder;
run;
 
/*data stat09;*/
/*set stat08;*/
/*keep page paramn avisitn statorder statistic;*/
/*run; */
 
/*----------------------------------------------------------
Create macro variables for header count in proc report
----------------------------------------------------------*/
 
proc sql noprint;
   select count(distinct usubjid) into : n1 from adsl02 where treatment=1;
   select count(distinct usubjid) into : n2 from adsl02 where treatment=2;
quit;
/*   proc freq data=adsl01;*/
/* table treatment; run; */

/*----------------------------------------------------------
````````````````Report generation
----------------------------------------------------------*/
%rtf_output_style_setup(
  protocol=XXX01,
  population=%str(Safety Analysis Set),
  pgm_path=%str(C:\XXX01\PROGRAMS\DRAFT\TFLs\ZZZ.sas)
); 
  
ods listing close;
ods rtf file="&outputpath.\lab_change.rtf" style=csgpool01;
 
/* */
title3 j=c "^S={foreground=blue fontweight=bold fontstyle=italic}Actual and Change from Baseline for Laboratory Tests";
title4 j=c "^S={foreground=blue fontweight=bold fontstyle=italic}Safety Analysis Set";


proc report data=stat08 nowd   headskip missing style(report)=[just=center  ] split='~';
   columns page paramn avisitn statorder 

/*handle the first header borders*/
/*   remove all borders*/
 ("(*ESC*)S={
	      /* drop all bottom lines */
      borderbottomwidth=0
      borderbottomstyle=none
      borderbottomcolor=white

      /* drop border lines */
      bordertopwidth=0
      borderleftwidth=0
      borderrightwidth=0
      bordertopstyle=none
      borderleftstyle=none
      borderrightstyle=none
      bordertopcolor=white
      borderleftcolor=white
      borderrightcolor=white
	just=c" statistic)
/*   remove all borders except botton*/
   ("(*ESC*)S={borderbottomcolor=black borderbottomwidth=1 just=c       
   bordertopwidth=0
   borderleftwidth=0
   borderrightwidth=0

   bordertopstyle=none
   borderleftstyle=none
   borderrightstyle=none

   bordertopcolor=white
   borderleftcolor=white
   borderrightcolor=white} Completers of Week 24~(N=%cmpres(&n1))" trt_11 trt_12 trt_13)
/*   remove all borders  */
   ("(*ESC*)S={
	      /* drop all bottom lines */
      borderbottomwidth=0
      borderbottomstyle=none
      borderbottomcolor=white

      /* drop border lines */
      bordertopwidth=0
      borderleftwidth=0
      borderrightwidth=0
      bordertopstyle=none
      borderleftstyle=none
      borderrightstyle=none
      bordertopcolor=white
      borderleftcolor=white
      borderrightcolor=white
	just=c" dummy)
/*   remove all borders except botton*/
   ("(*ESC*)S={borderbottomcolor=black borderbottomwidth=1 just=c       
   bordertopwidth=0
   borderleftwidth=0
   borderrightwidth=0

   bordertopstyle=none
   borderleftstyle=none
   borderrightstyle=none

   bordertopcolor=white
   borderleftcolor=white
   borderrightcolor=white} Total~(N=%cmpres(&n2))" trt_21 trt_22 trt_23);


   define page/ order noprint;
   define paramn/order noprint;
   define avisitn/order noprint;
   define statorder/order noprint;

   define dummy/display "" style(column)=[cellwidth=0.05in ] ;
 
   define statistic /order " " style(column)=[cellwidth=1.5 in protectspecialchars=off] ;
   define trt_11 /"Baseline~Value" style(column)=[cellwidth=1.2in] ;
   define trt_12 /"Value" style(column)=[cellwidth=1.2in]   ;
   define trt_13 /"Change" style(column)=[cellwidth=1.2in]   ;
 
   define trt_21 /"Baseline~Value" style(column)=[cellwidth=1.2in] ;
   define trt_22 /"Value" style(column)=[cellwidth=1.2in]   ;
   define trt_23 /"Change" style(column)=[cellwidth=1.2in]   ;
 
   compute after avisitn;
        line @1 "";
   endcomp;
 
   break after page/page;
 
run;


ods rtf close;
 

/*MMRM ? "At each visit, how different are the groups?"*/
/*Random intercept/slope ? "How do the trajectories differ over time?"*/



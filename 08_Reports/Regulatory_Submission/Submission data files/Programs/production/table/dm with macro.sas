/**********************************************************************
 Program:    dm_chracters.sas
 Purpose:    create a dm table
 Author:     Daniel
 Date:       2026-01-03
**********************************************************************/



/*=========================================================
Programming for the Task
=========================================================*/

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
Read input datasets
=========================================================*/
 
 
data adsl01;
   set adam.adsl;
   where ITTFL="Y";     /*using itt*/
run;
 
/*=========================================================
Create a variable named 'treatment' to hold report level column groupings<br/>
Also create duplicate rows for presenting total column
=========================================================*/
 
data adsl02;
   set adsl01;

   treatment=trt01an;
   output;
   treatment=98;  /*3 is overall */
   output;
run;
 
/*=========================================================
Create formats for preloading to create full template for sparse data
=========================================================*/
 
/*----------------------------------------------------------
Notice the creation of numeric and character formats for categorical variables
----------------------------------------------------------*/
 
 
proc format;
/*   value treatment*/
/*      1=1*/
/*      2=2*/
/*      3=3*/
/*4=4;*/
/* */
/*   value sexn*/
/*      99=99*/
/*      1=1*/
/*      2=2;*/
/* */
/*   value aracen*/
/*      99=99*/
/*      1=1*/
/*      2=2*/
/*      3=3*/
/*      4=4;*/
 
   value sexn_disp
      99="Missing"
      1="Male"
      2="Female";
 
   value aracen_disp
      99="Missing"
      1="White"
      2="Black or African American"
      3="Asian"
      4="Other";

	 invalue $genderfmt     /*invalue for text */
	  "M" = 1
	  "F" = 2;

	  	 invalue $racefmt     /*invalue for text */
	  "WHITE" = 1
	  "BLACK OR AFRICAN AMERICAN" = 2
"AMERICAN INDIAN OR ALASKA NATIVE" = 3;
run;
 
 
/*=========================================================
```````Create numeric variables for categorical variables, also setting them to 0 for missing values
=========================================================*/
 
 
data adsl03;
   set adsl02;
   keep usubjid treatment sexn  aracen age weightbl  heightbl  bmibl ;
sexn=input(input(sex, $genderfmt.),8.);
aracen=input(input(race,$racefmt.),8.);
   if missing(sexn) then sexn=99;
   if missing(aracen) then aracen=99;    /*if missing*/*/;
run;
/* proc contents data=adsl03 varnum;run; */
/*proc freq data=adsl02 ;*/
/*table sex race;*/
/*run;  */

/*=========================================================
Get treatment totals into a dataset and into macro variables(for column headers)
=========================================================*/
 
/*----------------------------------------------------------
Get treatment `````````` totals based on actual data
----------------------------------------------------------*/
proc sql;
   create table trttotal_pre as
      select treatment  ,
      count(distinct usubjid)    as trttotal   /*calculate the n of three groups*/
      from adsl02
      group by treatment;
quit;
 
/*----------------------------------------------------------
Create dummy dataset for treatement totals
----------------------------------------------------------*/
 
data dummy_pre;
   do treatment=0,54,81,98;
      output;
   end;
run;
 
/*----------------------------------------------------------
Merge actual counts with dummt counts
----------------------------------------------------------*/
 
data trttotals;
   merge dummy_pre(in=a)  trttotal_pre(in=b);
   by treatment;
   if trttotal=. then trttotal=0;
run;
 
 
/*----------------------------------------------------------
Create macro variables to present treatment totals in column headers of report
----------------------------------------------------------*/
 
proc sql noprint;
   select count(distinct usubjid) into :n1 from adsl02 where treatment=0;
   select count(distinct usubjid) into :n2 from adsl02 where treatment=54;
   select count(distinct usubjid) into :n3 from adsl02 where treatment=81;  
   select count(distinct usubjid) into :n4 from adsl02 where treatment=98;  /*create three macro variables*/
quit;
 
/*=========================================================
Create a macro for obtaining counts and percentages for ````````categorical variables
=========================================================*/
 
/*----------------------------------------------------------
Macro flow: <br/>
Obtain non-missing values as denominator<br/>
Obtain level counts using proc summary using completetypes,preloadfmt and nway options<br/>
Merge level counts with denominator counts<br/>
Calculate percentages<br/>
Transpose the dataset to get treatments as columns<br/>
----------------------------------------------------------*/
 
 
%macro count_percent(var=,
                label=,
                group=
               );
 
*-------------------------------------------;
*obtain non-missing values as denominator;
*-------------------------------------------;
/* %let var=sexn;*/
/*           %let  label=%str(Sex);*/
/*            %let  group=1;*/

proc sql;
   create table &var._denoms as
   select treatment,count(distinct usubjid) as denom
   from adsl03
   where &var not in (., 99)
   group by treatment
   order by treatment;
quit;
 
data &var.denoms;
   merge dummy_pre &var._denoms;
   by treatment;
   if denom =. then denom=0;
run;
 
*-------------------------------------------;
*obtain level counts using proc summary using completetypes,preloadfmt and nway options;
*-------------------------------------------;
 
proc summary data=adsl03 completetypes nway;
   class treatment /preloadfmt;
   class &var./preloadfmt;
   where not missing(&var.);
/*   format  &var. &var.. treatment treatment.;*/
   output out=&var._stats(drop=_type_ rename=(_freq_=count));
run;
 
*---------------------------------------;
*merge level counts with denominator counts;
*---------------------------------------;
 
*numerator counts;
 
proc sort data=&var._stats;
   by treatment ;
run;
 
*denominator counts;
 
proc sort data=&var._denoms;
   by treatment ;
run;
 
data &var._stats2;
   merge &var._stats &var._denoms;
   by treatment ;
run;
 
*-----------------------------------------------;
*calculate percentages;
*-----------------------------------------------;
 
data &var._stats3;
   set &var._stats2;
   length label statistic $50 cp $20;
 
   label="&label.";
   group=&group.;
 
   intord=&var.;
 
   statistic=put(&var.,&var._disp.);    /*use sex or race format*/
 
 
   if count ne 0 and intord ne 99 then cp=put(count,3.)|| ' ('||put(round(count*100/denom,0.1),5.1)||'%)';
   else cp=put(count,3.);
 
run;
 
*-----------------------------------------------;
*Transpose the dataset to get treatments as columns;
*-----------------------------------------------;
 
proc sort data=&var._stats3;
   by  group intord label statistic;
run;
 
proc transpose data=&var._stats3 out=&var._stats4;
   by  group intord label statistic;
   var cp;
   id treatment;
run;
 
/*proc contents data= sexn_stats4 varnum;*/
/*run; */

data final_stats_&var.;
   length c1-c6 $200;    /*three groups*/
   set &var._stats4;
   if intord=0 and compress(_3)="0" then delete;
   c1=label;
   c2=statistic;
   c3=_0;
   c4=_54;
   c5=_81;
   c6=_98;
 
   keep group  intord c1-c6 ;
run;
 
proc sort data=final_stats_&var.;
   by  group intord;
run;
%mend;
 
 
/*=========================================================
Call the macro to get counts and percentages for sex and race variables
=========================================================*/
/*----------------------------------------------------------
Notice the creation of group and order variables within macro
----------------------------------------------------------*/
%count_percent(var=sexn,
            label=%str(Sex),
             group=1
            );
 
 
%count_percent(var=aracen,
            label=%str(Race),
             group=2
            );
 
 
/*=========================================================
Create macro to get ```````````desciptive statistics for numeric variables
=========================================================*/
 
/*----------------------------------------------------------
Macro flow:<br/>
Get descriptive statistics<br/>
Process the statistics as per presentation needs<br/>
Transpose the statistics such that they become rows<br/>
Transpose the data such that treatments become columns<br/>
----------------------------------------------------------*/
 
 
%macro descriptive(
      var=,
      label=,
      group=,
      n=,
      mean=,
      sd=,
      min=,
      median=,
      max=
      );
*------------------------------------------------------------------------------;
*Get descriptive statistics;
*------------------------------------------------------------------------------;
/*      %let var=age;*/
/*      %let label=%str(Age (Years));*/
/*      %let group=3;*/
/*      %let n=3.;*/
/*      %let mean=5.1;*/
/*      %let sd=5.1;*/
/*      %let min=3.;*/
/*      %let median=5.1;*/
/*       %let max=3.;*/
/*	  %put &max;*/

proc summary data=adsl03  nway;     /*age summary stats*/
   class treatment;  /*by treatment*/
   where not missing(&var.);
   var &var.;
   output out=&var._stats(drop=_type_ _freq_)
   n= mean= std= min= median= max= /autoname;
run;
 
/*proc contents data= age_stats varnum; run;*/
*------------------------------------------------------------------------------;
*Process the statistics as per presentation needs;
*------------------------------------------------------------------------------;
 
data &var._stats2;
   set &var._stats;
   if not missing(&var._n) then n=put(&var._n,&n.);   /*set these stats format and type*/
   if not missing(&var._mean) then mean=put(&var._mean,&mean.);
   if not missing(&var._stddev) then sd=put(&var._stddev,&sd.);
   if not missing(&var._min) then min=put(&var._min,&min.);
   if not missing(&var._median) then median=put(&var._median,&median.);
   if not missing(&var._max) then max=put(&var._max,&max.);
 
   drop &var._:;
run;
 
*------------------------------------------------------------------------------;
*Transpose the statistics such that they become rows;
*------------------------------------------------------------------------------;
 
proc transpose data=&var._stats2 out=&var._stats3(drop=_name_) label=statistic;
   by   treatment;
   var n mean sd min median max;
   label n="n"
         mean="Mean"
         sd="SD"
         min="Min"
         median="Median"
         max="Max";
run;
 
data &var._stats4;
   set &var._stats3;
   length label $50;
 
   label="&label.";
   group=&group.;
 
   select(statistic);
      when("n") intord=1;
      when ("Mean") intord=2;
      when ("SD") intord=3;
      when ("Min") intord=4;
      when ("Median") intord=5;
      when ("Max") intord=6;
   otherwise;
   end;
run;
 
*------------------------------------------------------------------------------;
*Transpose the data such that treatments become columns;
*------------------------------------------------------------------------------;
 
proc sort data=&var._stats4;
   by  group intord label statistic;
run;
 
proc transpose data=&var._stats4 out=_final_stats_&var.;
   by  group intord label statistic;
   var col1;
   id treatment;
run;
 
data final_stats_&var.;
   set _final_stats_&var.;
   length c1-c6 $200;
   c1=label;
   c2=statistic;
   c3=_0;
   c4=_54;
   c5=_81;
   c6=_98;
   keep group  intord c1-c6 ;
run;
 
%mend;
 
/*proc contents data=_final_stats_age varnum; run; */
 
/*=========================================================
Call the descriptive macro for age, height, weight and bmi
=========================================================*/
 
 
%descriptive(
      var=age,
      label=%str(Age (Years)),
      group=3,
      n=3.,
      mean=5.1,
      sd=5.1,
      min=3.,
      median=5.1,
      max=3.
      );
 
 
%descriptive(
      var=weightbl,
      label=%str(Weight (Kg)),
      group=4,
      n=3.,
      mean=6.2,
      sd=6.2,
      min=5.1,
      median=6.2,
      max=5.1
      );
 
%descriptive(
      var=heightbl,
      label=%str(Height (cm)),
      group=5,
      n=3.,
      mean=5.1,
      sd=5.1,
      min=3.,
      median=5.1,
      max=3.
      );
 
%descriptive(
      var=bmibl,
      label=%str(BMI (kg/m**2)),
      group=6,
      n=3.,
      mean=7.3,
      sd=7.3,
      min=6.2,
      median=7.3,
      max=6.2
      );
 
 
/*=========================================================
``````````Combine all datasets containing counts/percentages and descriptive statistics
=========================================================*/
 
 
data final;
   set final_stats_:;    /*merge all final datasets*/
   if group =6 then page=2;
   else page=1;
run;
 
proc sort data=final;
   by page group intord;
run;
 
/*proc contents data= final_stats_sexn varnum; run; */
/*proc contents data= final_stats_age varnum; run; */
 
/*=========================================================
```````````Report generation
=========================================================*/
%rtf_output_style_setup(
  protocol=XXX01,
  population=%str(Randomized Analysis Set),
  pgm_path=%str(C:\XXX01\PROGRAMS\DRAFT\TFLs\ZZZ.sas)
); 
 
title3 "^S={foreground=blue fontweight=bold fontstyle=italic}Demographic Characteristics";
title4 "^S={foreground=blue fontweight=bold fontstyle=italic}Intent-to-Treat";
 
ods listing close;
options orientation=landscape nodate nonumber nobyline;
ods rtf file="&outputpath.\dm_macro_characteristics.rtf" style=csgpool01;
 
 
proc report data = final center headline headskip nowd split='~' missing style(report)=[just=center]
   style(header)=[just=center];
 
   column page group c1 intord c2 c3 c4 c5 c6 ;
 
   define group/order noprint;
   define intord /order noprint;
   define page/order noprint;
 
   define c1/width=30 "Parameter" order style(column)=[cellwidth=1.5in protectspecialchars=off] style(header)=[just=left];
   define c2/width=30 "Category/~Statistic" style(column)=[cellwidth=2in protectspecialchars=off] style(header)=[just=left];
 
   define c3/"Placebo" "(N=%cmpres(&n1))"  style(column)=[cellwidth=1.7in just=center] ;
   define c4/"Low dose" "(N=%cmpres(&n2))"  style(column)=[cellwidth=1.7in just=center]   ;
   define c5/"High dose" "(N=%cmpres(&n3))"  style(column)=[cellwidth=1.7in just=center]   ;
    define c6/"Total" "(N=%cmpres(&n4))"   style(column)=[cellwidth=1.7in just=center]   ;

   compute after group;
      line @1 "";
   endcomp;
 
   break after page/page;
run;
 
 
ods rtf close;
 
/*dm 'log' clear;*/
/*dm 'output' clear;*/
/*ods results clear;*/
/*proc datasets lib=work kill nolist;*/
/*quit;*/
/*libname mylib clear;*/
 

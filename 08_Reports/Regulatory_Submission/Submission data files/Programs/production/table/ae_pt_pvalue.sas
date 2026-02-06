/**********************************************************************
 Program:    ae_pt_pvalue.sas
 Purpose:    create ae pvalue
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
 
 
/*----------------------------------------------------------
Read input datasets
----------------------------------------------------------*/
 
data adae01;
    set adam.adae;
    where saffl="Y" and trtemfl="Y";
run;
 
 
data adsl01;
    set adam.adsl;
    where saffl="Y";
run;
 
 
/*=========================================================
Create variable named 'treatment' to hold report level column groupings
=========================================================*/
 
 
data adae02;
    set adae01;
    treatment=trtan;
    output;
run;
 
data adsl02;
   set adsl01;
    treatment=trt01an;
    output;
run;
 
/*=========================================================
```````````````Get treatment totals into a dataset and into macro variables (for column headers)
=========================================================*/
 
 
proc sql;
   create table trttotal_pre as
      select treatment,
      count(distinct usubjid) as trttotal
      from adsl02
      group by treatment;
quit;
 
/*----------------------------------------------------------
Create dummy dataset for treatement totals
----------------------------------------------------------*/
 
data dummy_pre;
   do treatment=0,54,81;
      output;
   end;
run;
 
/*----------------------------------------------------------
Merge actual counts with dummy counts
----------------------------------------------------------*/
 
data trttotals;
   merge dummy_pre(in=a) trttotal_pre(in=b);
   by treatment;
   if trttotal=. then trttotal=0;
run;
 
 
/*----------------------------------------------------------
Macro variables
----------------------------------------------------------*/
proc sql noprint;
   select count(distinct usubjid) into :n0 from adsl02 where treatment=0;
   select count(distinct usubjid) into :n54 from adsl02 where treatment=54;
   select count(distinct usubjid) into :n81 from adsl02 where treatment=81;
quit;
 
 
/*=========================================================
````````````````Obtaining actual counts-for the table
=========================================================*/
 
 
/*----------------------------------------------------------
Subject level count- top row
----------------------------------------------------------*/
 
 
proc sql noprint;
   create table sub_count as
   select "Overall" as label length=200,
   treatment,
   count(distinct usubjid) as count
   from adae02
   group by treatment;
quit;
 
/*----------------------------------------------------------
Preferred term level counts
----------------------------------------------------------*/
 
 
proc sql noprint;
   create table pt_count as
      select aedecod,treatment,
      count(distinct usubjid) as count
      from adae02
      group by aedecod,treatment;
quit;
 
 
/*----------------------------------------------------------
Combine toprow and PT level counts into single dataset
----------------------------------------------------------*/
 
 
data counts01;
   set sub_count pt_count;
run;
 
/*=========================================================
Create zero counts if an event is not present in a treatment
=========================================================*/
 
 
/*----------------------------------------------------------
Get all the available PT values
----------------------------------------------------------*/
 
proc sort data=counts01 out=dummy01(keep=aedecod label) nodupkey;
   by aedecod label;
run;
 
/*----------------------------------------------------------
Create a row for each treatment
----------------------------------------------------------*/
 
data dummy02;
   set dummy01;
   do treatment=0,54,81;
         output;
   end;
run;
 
/*=========================================================
Merge dummy counts with actual counts
=========================================================*/
 
proc sort data=dummy02;
   by aedecod label treatment;
run;
 
 
proc sort data=counts01;
   by aedecod label treatment;
run;
 
data counts02;
   merge dummy02(in=a) counts01(in=b);
   by aedecod label treatment;
   if count=. then count=0;
run;
 
 
/*=========================================================
```````````````Calculate percentages
=========================================================*/
 
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
   if count ne 0 then cp=put(count,3.)||" ("||put(count/trttotal*100,5.1)||"%)";
   else cp=put(count,3.);
run;
 
 
/*=========================================================
Create the label column
=========================================================*/
 
 
data counts05;
   set counts04;
   if missing(aedecod) then label=label;
   else if not missing(aedecod) then label=strip(aedecod);
run;
 
 
/*=========================================================
```````````````Transpose to obtain treatment as columns
=========================================================*/
 
 
proc sort data=counts05;
   by aedecod label ;
run;
 
proc transpose data=counts05 out=trans01 prefix=trt;
   by aedecod label;
   var cp;
   id treatment;
run;
 
 
data trans02;
   set trans01;
   keep aedecod c1 trt: label;
   c1=label;
run;
 /*----------------------------------------------------------
`````````````the above is ae descrptive table by treatment
----------------------------------------------------------*/
 
/*=========================================================
Calculate p-value using fisher exact test
=========================================================*/
 
/*----------------------------------------------------------
Note that p-value in this example is being created only for low dose vs placebo
----------------------------------------------------------*/
 
/*----------------------------------------------------------
``````````````Subset the low dose and placebo counts
----------------------------------------------------------*/
data events01;
   set counts05;
   where treatment in (0,54);
run;
 
/*----------------------------------------------------------
Get the number subjects with non-event
----------------------------------------------------------*/
/*----------------------------------------------------------
``````````````This count can be obtained by substracting the number of subjects with event from denominator
----------------------------------------------------------*/
 
data events02;
   set events01;
   event=1;
   output;

   count=trttotal-count;  /*non event */
   event=2;
   output;
run;
 
 
/*----------------------------------------------------------
`````````````Check if there is any aedecod        with 0 counts in both treatments
----------------------------------------------------------*/
/*----------------------------------------------------------
0 counts can be present in both treatments when there are more than 2 treatment groups</br>
as other treatment groups may have events with no events in treatments under consideration for p-value
----------------------------------------------------------*/
 
proc sql;
   create table nonzerodecods as
      select distinct aedecod,label
      from events01
      group by aedecod,label
      having sum(count) gt 0;    /*delete having 0 counts in both treatments*/
quit;
 
proc sql;
   create table events03 as
      select a.*
      from events02 as a
      inner join
      nonzerodecods as b
      on a.aedecod=b.aedecod and a.label=b.label;
quit;
 
/*----------------------------------------------------------
`````````````Run proc freq with required options  by aedecode and label    to get fisher exact p-value
`````````````based on the intermediate datasets not original datasets
----------------------------------------------------------*/
 
proc sort data=events03;
   by aedecod label treatment event;
run;
 
proc freq data=events03;
    by aedecod label;    /*by aedecode */

    tables treatment*event/fisher;   /*2 by 2*/
    exact fisher;
    weight count;    /*weight*/

    output out=p_val01 fisher;   /*three fisher results*/
run;
 
 
/*----------------------------------------------------------
Process p-value dataset to create variable to hold p-value
----------------------------------------------------------*/
 
data p_val02;
    set p_val01;
    length pval $10;
    if . lt xp2_fish lt 0.0001 then pval="<.0001";
    else pval=strip(put(xp2_fish,6.4));
run;
 
/*----------------------------------------------------------
```````````````````Merge the p-value dataset to the dataset containing treatments as columns
----------------------------------------------------------*/
 
proc sort data=trans02;
   by aedecod label;
run;
 
data trans03;
   merge trans02(in=a) p_val02(in=b keep=aedecod label pval);
   by aedecod label;
   if a;
   if aedecod="" and label="Overall" then ord=1;
   else ord=2;
   if missing(pval) then pval="-";
run;
 
/*=========================================================
`````````````````Report generation
=========================================================*/
 
%rtf_output_style_setup(
  protocol=XXX01,
  population=%str(Safety Analysis Set),
  pgm_path=%str(C:\XXX01\PROGRAMS\DRAFT\TFLs\ZZZ.sas)
); 
 

footnote5 j=left "[1] Fisher's exact test." ;
 
title3 "^S={foreground=blue fontweight=bold fontstyle=italic}TEAE by Preferred Term - with fisher's exact test p-value";
title4 "^S={foreground=blue fontweight=bold fontstyle=italic}Safety Analysis Set";
 
ods listing close;
ods rtf file="&outputpath.\ae_pt_pvalue.rtf" style=csgpool01;
 
proc report data=trans03 nowd headline headskip missing style(report)=[just=center]
   style(header)=[just=center];
   columns ord aedecod c1  trt0 trt54 trt81 pval;
   define aedecod/ order noprint;
   define ord/ order noprint;
 
   define c1 /order 'Preferred Term' style(column)=[cellwidth=3.7in protectspecialchars=off]
            style(header)=[just=left] ;
   define trt0/"Placebo" "(N=%cmpres(&n0))" "  n   (%)" style(column)=[cellwidth=1.2in just=center] ;
   define trt54/"Low Dose" "(N=%cmpres(&n54))" "  n   (%)" style(column)=[cellwidth=1.2in just=center]   ;
   define trt81/"High Dose" "(N=%cmpres(&n81))" "  n   (%)"  style(column)=[cellwidth=1.2in just=center]   ;    /*report the third group*/
   define pval/"Low dose" "vs" "Placebo" "p-value [1]" style(column)=[cellwidth=0.6in];
 
   compute after ord;
        line @1 "";
   endcomp;
 
run;
 
ods rtf close;
 

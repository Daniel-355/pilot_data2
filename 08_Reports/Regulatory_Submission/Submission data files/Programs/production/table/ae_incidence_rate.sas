/**********************************************************************
 Program:    ae_incidence_rate.sas
 Purpose:    create a ae incidence rate
 Author:     Daniel
 Date:       2026-01-25
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
Create variable named 'treatment' to hold report level column groupings<br/>
Also, create a variable named dur to hold treatment duration to use in subject year calculation
=========================================================*/
 
 
data adae02;
    set adae01;
    treatment=trtan;
    if astdt ne . and trtsdt ne . then aval=astdt-trtsdt+1;
    output;
run;
 
data adsl02;
   set adsl01;
    treatment=trt01an;
    output;
run;
 
/*=========================================================
Get treatment totals into a dataset and into macro variables (for column headers)
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
Macro variables for subject count
----------------------------------------------------------*/
proc sql noprint;
   select count(distinct usubjid) into :n0 from adsl02 where treatment=0;
   select count(distinct usubjid) into :n54 from adsl02 where treatment=54;
   select count(distinct usubjid) into :n81 from adsl02 where treatment=81;
quit;
 
 
/*=========================================================
Create a dataset to ````````````have each preferred term and soc in data for each subject
=========================================================*/
 
/*----------------------------------------------------------
Fetch the unique SOC and DECOD values seen in data
----------------------------------------------------------*/
 
proc sort data=adae02 out=dummy01(keep=aebodsys aedecod) nodupkey;
   by aebodsys aedecod;
run;
 
/*----------------------------------------------------------
Create a cross tabulation using the unique soc and decod values for every safety subject
----------------------------------------------------------*/
 
proc sql;
   create table dummy02 as
      select a.*,b.*
      from adsl02 as a,dummy01 as b
   ;
quit;
 
/*=========================================================
Merge dummy and actual datasets and create a flag variable to identify if an event existed for a subject
=========================================================*/
 
proc sort data=adae02;
   by usubjid aebodsys aedecod;
run;
 
proc sort data=dummy02;
   by usubjid aebodsys aedecod;
run;
 
data adae03;
   merge adae02(in=a) dummy02(in=b);
   by usubjid trtsdt treatment aebodsys aedecod;
   if a and b then event="Y";
   else event="N";
run;
 
data adae04;
   set adae03;
   if event="N" then do;
      if aval=. then aval=trtedt-trtsdt+1;
   end;
run;
 
/*=========================================================
Create 3 separate datasets for each count level, and keep the earliest record
``````````````level 1 2 3 
=========================================================*/
 
/*----------------------------------------------------------
For Overall row
----------------------------------------------------------*/
 
proc sort data=adae04 out=level01_pre;
   by usubjid treatment aval;
run;
 
data level01;
   set level01_pre;
   by usubjid treatment aval;
   if first.treatment;
run;
 
/*----------------------------------------------------------
For SOC Level
----------------------------------------------------------*/
 
proc sort data=adae04 out=level02_pre;
   by usubjid aebodsys treatment aval;
run;
 
data level02;
   set level02_pre;
   by usubjid aebodsys treatment aval;
   if first.treatment;
run;
 
/*----------------------------------------------------------
For SOC and PT Level
----------------------------------------------------------*/
 
proc sort data=adae04 out=level03_pre;
   by usubjid aebodsys aedecod treatment aval;
run;
 
data level03;
   set level03_pre;
   by usubjid aebodsys aedecod treatment aval;
   if first.treatment;
run;
 
/*=========================================================
Obtaining actual counts-for the table
=========================================================*/
 
 
/*----------------------------------------------------------
Top row counts
----------------------------------------------------------*/
 
 
proc sql noprint;
   create table sub_count as
   select "Overall" as label length=200,
   treatment,
   sum(event="Y") as count,sum(aval)/365.25 as subjyr  /*``````````only count once, aval =dur*/
   from level01
   group by treatment;
quit;
 
 
/*----------------------------------------------------------
SOC level counts
----------------------------------------------------------*/
 
 
proc sql noprint;
   create table soc_count as
      select aebodsys, treatment,
      sum(event="Y") as count,sum(aval)/365.25 as subjyr
      from level02
      group by aebodsys,treatment;
quit;
 
 
/*----------------------------------------------------------
Preferred term level counts
----------------------------------------------------------*/
 
 
proc sql noprint;
   create table pt_count as
      select aebodsys,aedecod,treatment,
      sum(event="Y") as count,sum(aval)/365.25 as subjyr
      from level03
      group by aebodsys,aedecod,treatment;
quit;
 
 
/*----------------------------------------------------------
Combine toprow, SOC, and PT level counts into single dataset
----------------------------------------------------------*/
 
 
data counts01;
   set sub_count soc_count pt_count;
run;
 
 
/*=========================================================
Calculate percentages
=========================================================*/
 
proc sort data=counts01;
   by treatment;
run;
 
proc sort data=trttotals;
   by treatment;
run;
 
data counts03;
   merge counts01(in=a) trttotals(in=b);
   by treatment;
   if a;
run;
 
data counts04;
   set counts03;
   length cp $30;
   if subjyr ne 0 then cp=put(count,3.)||"["||put(subjyr,8.2)||"] ("||put(count/subjyr*100,6.1)||")";   /*combine stats*/
   else cp=put(count,3.);
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
Transpose to obtain treatment as columns
=========================================================*/
 
 
proc sort data=counts05;
   by aebodsys aedecod label ;
run;
 
proc transpose data=counts05 out=trans01 prefix=trt;
   by aebodsys aedecod label;
   var cp;
   id treatment;
run;
 
 
data trans02;
   set trans01;
   keep aebodsys aedecod c1 trt: label;
   c1=label;
run;
 
 
/*=========================================================
Create variables to sort the SOCs by descending frequency in high dose and also sort PTs by descending frequency in high dose within each SOC
=========================================================*/
 
/*----------------------------------------------------------
Extract counts from high dose column (trt81)
----------------------------------------------------------*/
data trans03;
   set trans02;
   cnt81=input(scan(trt81,2,'[]'),best.);
run;
 
 
/*----------------------------------------------------------
Separate top row, soc rows and pt rows into separate datasets
----------------------------------------------------------*/
 
data section0 section1 section2;
   set trans03;
   if label="Overall" and aebodsys="" and aedecod="" then output section0;
   if aebodsys ne "" and aedecod="" then output section1;
   if aedecod ne "" then output section2;
run;
 
 
/*----------------------------------------------------------
Create an order variable for top row
----------------------------------------------------------*/
data section0;
   set section0;
   section0ord+1;
run;
 
/*----------------------------------------------------------
Create order variable for SOC rows by sorting based on required variables
----------------------------------------------------------*/
proc sort data=section1;
   by descending cnt81 aebodsys;
run;
 
data section1;
   set section1;
   by descending cnt81 aebodsys;
   section1ord+1;
   section0ord=999;
run;
 
 
/*----------------------------------------------------------
Create order variable for PT rows by sorting based on required variables within each SOC
----------------------------------------------------------*/
 
proc sort data=section2;
   by aebodsys descending cnt81 aedecod;
run;
 
data section2;
   set section2;
   by aebodsys descending cnt81 aedecod;
   section2ord+1;
   section0ord=999;
run;
 
 
/*----------------------------------------------------------
Bring the SOC sort order variable into PT rows dataset
----------------------------------------------------------*/
 
proc sql;
   create table section2_2 as
      select a.*,b.section1ord
      from section2 as a
      left join
      section1 as b
      on a.aebodsys=b.aebodsys;
quit;
 
 
/*----------------------------------------------------------
Combine all datasets after creating sort order variables
----------------------------------------------------------*/
data final;
   set section0 section1 section2_2;
run;
 
 
/*----------------------------------------------------------
Sort the final dataset using section sort order variables
----------------------------------------------------------*/
 
proc sort data=final;
   by  section0ord section1ord section2ord;
run;
 
 
/*=========================================================
Report generation
=========================================================*/
 
%rtf_output_style_setup(
  protocol=XXX01,
  population=%str(Safety Analysis Set),
  pgm_path=%str(C:\XXX01\PROGRAMS\DRAFT\TFLs\ZZZ.sas)
); 
 
 
title3 "^S={foreground=blue fontweight=bold fontstyle=italic}Exposure Adjusted Subject Incidence Rate by SOC and PT";
title4 "^S={foreground=blue fontweight=bold fontstyle=italic}Safety Analysis Set";
 
ods listing close;
ods rtf file="&outputpath.\ae_incidence_rate.rtf" style=csgpool01;
 
proc report data=final nowd headline headskip missing style(report)=[just=center]
   style(header)=[just=center];
   columns section0ord section1ord section2ord c1  trt0 trt54 trt81;
   define section0ord/ order noprint;
   define section1ord/order noprint;
   define section2ord/order noprint;
 
   define c1 / "System Organ Class" '(*ESC*)R"\fi-420\li420 "Preferred Term' style(column)=[cellwidth=3.7in protectspecialchars=off]
            style(header)=[just=left] ;
   define trt0/"Placebo" "(N=%cmpres(&n0))" "  n   [subj-yr]  (r)" style(column)=[cellwidth=1.7in just=center] ;
   define trt54/"Low Dose" "(N=%cmpres(&n54))" "   n   [subj-yr]  (r)" style(column)=[cellwidth=1.7in just=center]   ;
   define trt81/"High Dose" "(N=%cmpres(&n81))"  "  n   [subj-yr]  (r)"  style(column)=[cellwidth=1.7in just=center]   ;
 
   compute after section1ord;
        line @1 "";
   endcomp;
 
run;
 
ods rtf close;

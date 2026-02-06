/**********************************************************************
 Program:    ae_event_descending.sas
 Purpose:    create ae event descending
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
Get treatment totals into a dataset and into ```````````macro variables (for column headers)
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
Obtaining actual counts-for the table for ``````````different levels 
=========================================================*/
 
 
/*----------------------------------------------------------
Subject level count- top row
----------------------------------------------------------*/
 
 
proc sql noprint;
   create table sub_count as
   select "Overall" as label length=200,
   treatment,
   count(distinct usubjid) as count    /*distinct usubjid: count once*/
   from adae02
   group by treatment;
quit;
 
 
/*----------------------------------------------------------
SOC level counts
----------------------------------------------------------*/
 
 
proc sql noprint;
   create table soc_count as
      select aebodsys, treatment,
      count(distinct usubjid) as count
      from adae02
      group by aebodsys,treatment;
quit;
 
 
/*----------------------------------------------------------
Preferred term level counts
----------------------------------------------------------*/
 
 
proc sql noprint;
   create table pt_count as
      select aebodsys,aedecod,treatment,
      count(distinct usubjid) as count
      from adae02
      group by aebodsys,aedecod,treatment;
quit;
 
 
/*----------------------------------------------------------
Combine toprow, SOC, and PT level counts into single dataset
----------------------------------------------------------*/
 
 
data counts01;
   set sub_count soc_count pt_count;
run;
 
/*=========================================================
Create zero counts if an event is not present in a treatment    `````````````create a empty table with zero 
=========================================================*/
 
 
/*----------------------------------------------------------
Get all the available SOC and PT values
----------------------------------------------------------*/
 
proc sort data=counts01 out=dummy01(keep=aebodsys aedecod label) nodupkey;
   by aebodsys aedecod label;
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
   by aebodsys aedecod label treatment;
run;
 
 
proc sort data=counts01;
   by aebodsys aedecod label treatment;
run;
 
data counts02;
   merge dummy02(in=a) counts01(in=b);
   by aebodsys aedecod label treatment;
   if count=. then count=0;
run;
 
 
/*=========================================================
````````````Calculate percentages
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
   if missing(aebodsys) and missing(aedecod) then label=label;
   else if not missing(aebodsys) and missing(aedecod) then label=strip(aebodsys);
   else if not missing(aebodsys) and not missing(aedecod) then label='(*ESC*)R"\pnhang\fi220\li220 "'||strip(aedecod);
run;
 
 
/*=========================================================
```````````Transpose to obtain treatment as columns
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
Create variables to sort the SOCs by descending frequency in high dose ```````and also sort PTs by descending frequency in high dose within each SOC
=========================================================*/
 
/*----------------------------------------------------------
Extract counts from high dose column (trt81)
----------------------------------------------------------*/
data trans03;
   set trans02;
   cnt81=input(scan(trt81,1,'('),best.);
run;
 
 
/*----------------------------------------------------------
Separate top row, soc rows and pt rows into separate datasets
----------------------------------------------------------*/
 
data section0 section1 section2;    /*output three datasets*/
   set trans03;
   if label="Overall" and aebodsys="" and aedecod="" then output section0;
   if aebodsys ne "" and aedecod="" then output section1;
   if aedecod ne "" then output section2;
run;
 
 
/*----------------------------------------------------------
`````````````Create an order variable for top row
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

      from section2 as a    /*use section2 as base dataset , proc sql no need sort*/
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
```````````Sort the final dataset using section sort order variables
----------------------------------------------------------*/
 
proc sort data=final;
   by  section0ord section1ord section2ord;
run;
 
 
/*=========================================================
``````````Create an additional row of SOC on each page when preferred terms of a SOC are continued onto next page
````````````````showcase soc if pt continue next page
=========================================================*/
 
/*----------------------------------------------------------
Create a page variable with the assumption that 25 observations will be printed on a page
----------------------------------------------------------*/
 
data final01;
   set final;
   if mod(_n_,25)=1 then page+1;    /*remainder*/
   intord=_n_;
run;
 
/*----------------------------------------------------------
```````````Check if on each new page the SOC is equivalent to label row, if not output the record
`````````````create intord-0.1 then sort
----------------------------------------------------------*/
 
proc sort data=final01;
   by page intord;
run;
data pagecont01;
   set final01;
   by page intord;
   if first.page and page ne 1 then do;
      if aebodsys ne label then output;
   end;
 
   keep aebodsys aedecod label c1 intord page section0ord section1ord section2ord;
run;
 
data pagecont02;
   set pagecont01;
   intord=intord-0.1;
   c1=aebodsys;
run;
 
/*----------------------------------------------------------
Combine the SOC record subsetted in above step to actual data
----------------------------------------------------------*/
data final02;
   set final01 pagecont02;
   by page intord;
run;
 
/*=========================================================
```````````Report generation
=========================================================*/
 
 
%rtf_output_style_setup(
  protocol=XXX01,
  population=%str(Safety Analysis Set),
  pgm_path=%str(C:\XXX01\PROGRAMS\DRAFT\TFLs\ZZZ.sas)
); 
 
 
title3 "^S={foreground=blue fontweight=bold fontstyle=italic}Treatment-Emergent Adverse Events by descending frequency -SOC continued";
title4 "^S={foreground=blue fontweight=bold fontstyle=italic}Safety Analysis Set";


ods listing close;
options orientation=landscape nodate nonumber nobyline;

ods rtf file="&outputpath.\ae_soc_pt_descending.rtf" style=csgpool01;
 
proc report data=final02 nowd headline headskip missing style(report)=[just=center]
   style(header)=[just=center];
   columns page section0ord section1ord section2ord c1  trt0 trt54 trt81;
 
   define page/order noprint;
   define section0ord/ order noprint;
   define section1ord/order noprint;
   define section2ord/order noprint;
 
   define c1 / "System Organ Class" '(*ESC*)R"\fi-420\li420 "Preferred Term' style(column)=[cellwidth=3.7in protectspecialchars=off]
            style(header)=[just=left] ;
   define trt0/"Placebo" "(N=%cmpres(&n0))" "  n   (%)" style(column)=[cellwidth=1.7in just=center] ;
   define trt54/"Low Dose" "(N=%cmpres(&n54))" "  n   (%)" style(column)=[cellwidth=1.7in just=center]   ;
   define trt81/"High Dose" "(N=%cmpres(&n81))" "  n   (%)"  style(column)=[cellwidth=1.7in just=center]   ;
 
   compute after section1ord;
        line @1 "";
   endcomp;
 
   break after page/page;
 
run;
 
ods rtf close;

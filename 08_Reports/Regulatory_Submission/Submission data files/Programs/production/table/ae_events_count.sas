/**********************************************************************
 Program:    ae_events_count.sas
 Purpose:    create a ae count
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
 
/*----------------------------------------------------------
Subset the treatment-emergent adverse events of safety subjects from adae using where statement in a data step
Subset the safety subjects from adsl using where statement in a data step
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
/*----------------------------------------------------------
Creating a common named variable in both the datasets such that merging becomes easy downstream

----------------------------------------------------------*/
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
Get treatment totals into a dataset
=========================================================*/
 
/*----------------------------------------------------------
Get the treatment totals based on the data present
----------------------------------------------------------*/
 
/*----------------------------------------------------------
Count the number of subjects in each treatment using proc sql
`````````````create n for each group, no total column
----------------------------------------------------------*/
proc sql;
   create table trttotals_pre as
   select treatment,count(distinct usubjid) as trttotal
   from adsl02
   group by treatment;
quit;
 
 
/*----------------------------------------------------------
Create dummy dataset to hold all treatment levels
----------------------------------------------------------*/
/*----------------------------------------------------------
Create a dataset containing one row for each possible treatment using do loop, with an output statment inside the loop
----------------------------------------------------------*/
data dummytrt;
   do treatment=0,54,81;
     output;
   end;
run;
 
 
/*----------------------------------------------------------
Merge the dummy and actual treatment levels
----------------------------------------------------------*/
/*----------------------------------------------------------
Do a full merge such that a record gets created for each possible treatment
If a treatment level is not present in actual data then the variable trttotal will have a null value
Set trttotal to 0 when it is null using a conditional if statement
----------------------------------------------------------*/
data trttotals;
   merge dummytrt trttotals_pre ;
   by treatment;
   if missing(trttotal) then trttotal=0;
run;
 
 
/*=========================================================
Create macro variables to hold the treatment totals to use in column headings of report
=========================================================*/
 
/*----------------------------------------------------------
   Notice the use of _null_<br/>
   Notice the use of call symputx<br/>
   Notice the use of cats function in first argument of call symputx <br/>
   This code creates three macro variables named n0, n54 and n81 containing the number of safety subjects in each treatment
----------------------------------------------------------*/
 
data _null_;
   set trttotals;
   call symputx(cats("n",treatment),trttotal);
run;
 
/*=========================================================
Create dummy shell to present all rows irrespective of the presence of an event in a category
=========================================================*/
 
/*----------------------------------------------------------
Create each table row using output statement
----------------------------------------------------------*/
/*----------------------------------------------------------
Notice the creation of a corresponding numeric variable named ord for each row
----------------------------------------------------------*/
 
data dummy01;      /*````````````create a new empty table */
   length label $200;
   label="Adverse Events"; ord=1;output ;
   label="Drug-Related [1] Adverse Events"; ord=2;output;
   label="Deaths";ord=3;output;
   label="Serious Adverse Events [2]";ord=4; output;
   label="Drug-Related [1] Serious Adverse Events [2]"; ord=5; output;
   label="Adverse Events Leading to Permanent Discontinuation of Study Drug";ord=6; output;
   label="Drug-Related [1] Adverse Events Leading to Permanent Discontinuation of Study Drug"; ord=7; output;
run;
 
 
/*----------------------------------------------------------
Duplicate each table row across all treatment groups
----------------------------------------------------------*/
/*----------------------------------------------------------
Replicate reach row of dummy01 dataset thrice with treatment values of 0,54 and 81 using a do loop combined with output statement
----------------------------------------------------------*/
data dummy02;
   set dummy01;
   do treatment=0,54,81;
      output;
   end;
run;
 
/*=========================================================
Obtaining actual counts(with processing for each row)
=========================================================*/
/*----------------------------------------------------------
Notice the usage of 'union all corr' for appending data of all rows <br/>
Notice the usage of distinct in select clause for subject counts and absence of distinct in event counts
```````````calculate the numinator
----------------------------------------------------------*/
 
 
proc sql;
   create table counts01 as
   select treatment, 1 as ord,
   count(distinct usubjid) as subjects, count(usubjid ) as events
   from adae02
   where trtemfl="Y"  /*total adverse*/
   group by treatment
 
   union all corr
 
   select treatment, 2 as ord,
   count(distinct usubjid) as subjects, count(usubjid ) as events
   from adae02
   where upcase(aerel) in ("POSSIBLE" "PROBABLE")  /*related adverse*/
   group by treatment
 
   union all corr
 
   select treatment, 3 as ord,
   count(distinct usubjid) as subjects, count(usubjid ) as events
   from adae02
   where aesdth="Y"    /*dealth*/
   group by treatment
 
   union all corr
 
   select treatment, 4 as ord,
   count(distinct usubjid) as subjects, count(usubjid ) as events
   from adae02
   where aeser="Y"    /*serious events*/
   group by treatment
 
   union all corr
 
   select treatment, 5 as ord,
   count(distinct usubjid) as subjects, count(usubjid ) as events
   from adae02
   where upcase(aerel) in ("POSSIBLE" "PROBABLE") and aeser="Y"   /*related and serious*/
   group by treatment
 
   union all corr
 
   select treatment, 6 as ord,
   count(distinct usubjid) as subjects, count(usubjid ) as events
   from adae02
   where upcase(aeacn)="DRUG WITHDRAWN"   /*adverse and withdraw*/
   group by treatment
 
   union all corr
 
   select treatment, 7 as ord,
   count(distinct usubjid) as subjects, count(usubjid ) as events
   from adae02
   where upcase(aeacn)="DRUG WITHDRAWN" and upcase(aerel) in ("POSSIBLE" "PROBABLE")   /*related and adverse and withdraw*/
   group by treatment;
quit;
 
 
/*=========================================================
```````````````Merge dummy and actual counts to add zero 
=========================================================*/
/*----------------------------------------------------------
Sort the input datasets based on required variables using proc sort
Do a full merge so that we get a row from dummy dataset for the levels that we do not have in data
Set subject count and event count to zero if row is not present in actual counts data using conditional if statements
----------------------------------------------------------*/
proc sort data=dummy02;
   by ord treatment;
run;
 
proc sort data=counts01;
   by ord treatment;
run;
 
data counts02;
   merge dummy02(in=a) counts01(in=b);
   by ord treatment;
   if subjects=. then subjects=0;
   if events=. then events=0;
run;
 
/*=========================================================
````````````Calculate percentages
=========================================================*/
/*----------------------------------------------------------
Fetch the treatment totals into the dataset with table body counts<br>
Concatenate subject counts, percentage and event counts after converting to character format<br>
Notice that percentages are not represented when subject count is 0
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
run;
 
data counts04;
   set counts03;
   length cp $30;
   if subjects ne 0 then cp=put(subjects,3.)||" ("||put(subjects/trttotal*100,5.1)||"%) " ||put(events,3.);
   else cp=put(subjects,3.);
   keep ord label treatment cp;
run;
 
 
/*=========================================================
````````````Transpose the data to get treatments as columns
=========================================================*/
 
/*----------------------------------------------------------
Notice the usage of prefix option on proc transpose statement
----------------------------------------------------------*/
proc sort data=counts04;
   by ord label;
run;
 
proc transpose data=counts04 out=counts05(drop=_:) prefix=trt;
   by ord label;
   var cp;
   id treatment;
run;
 
/*=========================================================
``````````````Report generation
=========================================================*/
 
/*----------------------------------------------------------
Set up titles and footnotes
Route the output to an rtf file
----------------------------------------------------------*/

%rtf_output_style_setup(
  protocol=XXX01,
  population=%str(Safety Analysis Set),
  pgm_path=%str(C:\XXX01\PROGRAMS\DRAFT\TFLs\ZZZ.sas)
); 

title3 j=c "^S={foreground=blue fontweight=bold fontstyle=italic}Overview of Treatment-Emergent Adverse Events";
title4 j=c "^S={foreground=blue fontweight=bold fontstyle=italic}Safety Analysis Set";

ods listing close;
ods rtf file="&outputpath.\ae_events_count.rtf" style=csgpool01;
 
/*----------------------------------------------------------
Generate the report using proc report
----------------------------------------------------------*/
/*----------------------------------------------------------
Define the column widths using cellwidth option on define statement
Notice the usage of macro variables n0, n54 and n81 to present the subject counts in column headers of the report
----------------------------------------------------------*/
proc report data=counts05 nowd headline headskip missing style(report)=[just=center]
style(header)=[just=center];
   columns ord label  trt0 trt54 trt81;
   define ord/ order noprint;
   define label /order " " style(column)=[cellwidth=3.7in protectspecialchars=off] ;
   define trt0/"Placebo" "(N=%cmpres(&n0))" "   n     (%)     E" style(column)=[cellwidth=1.7in just=center] ;
   define trt54/"Low Dose" "(N=%cmpres(&n54))" "   n     (%)     E" style(column)=[cellwidth=1.7in just=center]   ;
   define trt81/"High Dose" "(N=%cmpres(&n81))" "   n     (%)     E" style(column)=[cellwidth=1.7in just=center]   ;
 
   compute after ord;
      line @1 "";
   endcomp;
run;
 
ods rtf close;

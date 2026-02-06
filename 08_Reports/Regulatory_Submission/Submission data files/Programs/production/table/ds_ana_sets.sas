/**********************************************************************
 Program:    ds_analysis_population.sas
 Purpose:    Prepare the analysis dataset ? Generate the overall results (two-row method) ? Calculate the denominator N for the column headers ? Calculate the counts for the table body ? Fill in zeros ? Combine n(%) ? Transpose ? Output RTF using PROC REPORT.
 Author:     Daniel
 Date:       2026-01-03
 Note:
				1 ai read interpret 
				2 ai write
				3 i edit
/***************************************************/
/*Version Control					        	   */
/*Version     Name          Date       Abstract    */
/* [1.0]     Daniel     2026-01-03  Initial Version*/
/*                                                 */
/***************************************************/




/*=========================================================
Programming for the Task
=========================================================*/

/*====================*/
/* include _setup.sas and /*open log*/  */
/*====================*/;
%let SETUP_PATH=%str(C:\Users\hed2\Downloads\Clinical_Trial_2025_DrugA_Phase3\08_Reports\Regulatory_Submission\Submission data files\_setup.sas);
%include "&SETUP_PATH";

%let PGNAME=ds_ana_sets;
%open_log(&PGNAME);

/*=========================================================
set Input and output 
=========================================================*/
%let PROGDIR  = &ROOT.\Programs\production\table\;
%let outputpath= &ROOT.\Outputs\table;


/*ADSL discrition*/

/*ID: STUDYID USUBJID SUBJID*/
/**/
/*Treatment: TRT01P TRT01PN TRT01A TRT01AN*//*contains character string vs the corresponding numeric code */
/**/
/*Population: ITTFL SAFFL EFFFL*/ /*randomization vs recieve a dose vs have a measurement*/
/**/
/*Demographics: AGE SEX RACE*/
/*baseline*/
/*Timeline (disease): TRTSDT TRTEDT RFSTDTC*//*RFSTDTC often defining a subject's overall study anchor (like consent or randomization), while TRTSDT specifically marks the date/time of the first dose of the actual study drug */
/**/
/*Completion Status: COMPLFL DISCONFL */ /*flags*/
/*discontinuation reasons*/


/*proc contents data=adsl varnum; run; */
/*# Variable Type Len Format Label */
/*/*study identifier*/*/
/*1 STUDYID Char 12   Study Identifier */
/*2 USUBJID Char 11   Unique Subject Identifier */
/*3 SUBJID Char 4   Subject Identifier for the Study */
/*4 SITEID Char 3   Study Site Identifier */
/*5 SITEGR1 Char 3   Pooled Site Group 1 */
/*/*planned arm*/*/
/*6 ARM Char 20   Description of Planned Arm */
/*7 TRT01P Char 20   Planned Treatment for Period 01 */
/*8 TRT01PN Num 8   Planned Treatment for Period 01 (N) */
/*9 TRT01A Char 20   Actual Treatment for Period 01 */
/*10 TRT01AN Num 8   Actual Treatment for Period 01 (N) */
/*11 TRTSDT Num 8 DATE9. Date of First Exposure to Treatment */
/*12 TRTEDT Num 8 DATE9. Date of Last Exposure to Treatment */
/*13 TRTDUR Num 8   Duration of Treatment (days) */
/*14 AVGDD Num 8   Avg Daily Dose (as planned) */
/*15 CUMDOSE Num 8   Cumulative Dose (as planned) */
/*/*demographic*/*/
/*16 AGE Num 8   Age */
/*17 AGEGR1 Char 5   Pooled Age Group 1 */
/*18 AGEGR1N Num 8   Pooled Age Group 1 (N) */
/*19 AGEU Char 5   Age Units */
/*20 RACE Char 32   Race */
/*21 RACEN Num 8   Race (N) */
/*22 SEX Char 1   Sex */
/*23 ETHNIC Char 22   Ethnicity */
/*/*population flag*/*/
/*24 SAFFL Char 1   Safety Population Flag */
/*25 ITTFL Char 1   Intent-To-Treat Population Flag */
/*26 EFFFL Char 1   Efficacy Population Flag */

/*27 COMP8FL Char 1   Completers of Week 8 Population Flag */
/*28 COMP16FL Char 1   Completers of Week 16 Population Flag */
/*29 COMP24FL Char 1   Completers of Week 24 Population Flag */
/*30 DISCONFL Char 1   Did the Subject Discontinue the Study? */
/*31 DSRAEFL Char 1   Discontinued due to AE? */
/*32 DTHFL Char 1   Subject Died? */
/*/*baseline vital signs*/*/
/*33 BMIBL Num 8   Baseline BMI (kg/m) */
/*34 BMIBLGR1 Char 6   Pooled Baseline BMI Group 1 */
/*35 HEIGHTBL Num 8   Baseline Height (cm) */
/*36 WEIGHTBL Num 8   Baseline Weight (kg) */
/*37 EDUCLVL Num 8   Years of Education */
/*/*onset date of disease*/*/
/*38 DISONSDT Num 8 DATE9. Date of Onset of Disease */
/*39 DURDIS Num 8   Duration of Disease (Months) */
/*40 DURDSGR1 Char 4   Pooled Disease Duration Group 1 */
/*/*reference start date*/*/
/*41 VISIT1DT Num 8 DATE9. Date of Visit 1 */
/*42 RFSTDTC Char 20   Subject Reference Start Date/Time */
/*43 RFENDTC Char 20   Subject Reference End Date/Time */
/*44 VISNUMEN Num 8   End of Trt Visit (Vis 12 or Early Term.) */
/*45 RFENDT Num 8 DATE9. Date of Discontinuation/Completion */
/*/*discontinuation reasons*/*/
/*46 DCDECOD Char 27   Standardized Disposition Term */
/*47 DCREASCD Char 18   Reason for Discontinuation */
/**/
/*48 MMSETOT Num 8   MMSE Total */;


/* set Overall and treatment code at beginning*/
%let OVERALL = 4;    
%let arm0 = 0;    
%let arm54 = 54;    
%let arm81 = 81;   

*==============================================================================;
*```````````create four analysis datasets, include the data file;
*==============================================================================;
 
 data adsl_new;
  set adam.adsl;

  length RANDFL FASFL SAFFL PPSFL $1;

  /* 1. Randomized Flag */
  RANDFL=ITTFL;
 
  /* 2. Full Analysis Set (ITT/FAS) */
FASFL=ITTFL;

  /* 3. Safety Population */
/*=SAFFL*/

  /* 4. generate Per Protocol Population */
  if FASFL="Y" and SAFFL="Y" and DCREASCD ne "Protocol Violation" then PPSFL="Y";
  else PPSFL="N";
run;
/*The PP set definition is more consistent with the protocol/PD specifications (don't rely solely on DCREASCD).*/
/*(Possibly in the ADAE/ADDS/custom-built PD datasets)*/
/*Simply using DCREASCD ? Protocol Violation is usually not sufficient to meet the requirement of "PP definition being auditable."*/
/*Informed Consent ?  /Excluded     Screening ? Screen Fail?       Randomized ?   Treated -     (withdraw inform consent)? Withdrawn/Completed*/
 
/*proc freq data= adsl;*/
/*table DCDECOD DCREASCD;*/
/*run;*/




*==============================================================================;
*Read and process the input datasets;
*==============================================================================;
/* randomized population + planned arm + calcualte overalll numbers*/
data adsl01;
    set adsl_new;
    where randfl="Y";      
run;
 
data adsl02;
    set adsl01;
    treatment=trt01pn;
    output;
 
    treatment=&OVERALL.;
    output;
run;
/* the Overall (Total) by using a "two-line-per-person" approach.*/

*==============================================================================;
*Get treatment totals and create macro variables;
*==============================================================================;
/*Multiple instances of hardcoding: */
/*proc sql noprint;*/
/*  create table trt_levels as*/
/*  select distinct treatment as treatment*/
/*  from adsl02*/
/*  where not missing(treatment)*/
/*  order by treatment;*/
/*quit;*/

data dummy_trttotals;
    do treatment=&arm0.,&arm54.,&arm81.,&OVERALL.;
        output;
    end;
run;
 



*------------------------------------------------------------------------------;
*get actual treatment totals, ;
*------------------------------------------------------------------------------;
/* get the overall numbers/ denominator in column header */
proc freq data=adsl02 ;
    tables   treatment /list missing  /*Treat missing values ??as a separate level for statistical analysis.*/  out=trttotals_pre  (rename=(count=trttotal) drop=percent);  /*calculate the percentages yourself later.*/
    where 1=1;  /*Maintain a consistent code structure.*/
run;
 
*------------------------------------------------------------------------------;
*merge actual and actual treatment totals;
*------------------------------------------------------------------------------;
 
 proc sort data=dummy_trttotals;
   by  treatment;
run;

data trttotals;
   merge dummy_trttotals(in=a)
         trttotals_pre(in=b);
   by treatment;
 
   if a and not b then trttotal=0;
run;
 
*------------------------------------------------------------------------------;
*create macro variables to use in the summary table;
*------------------------------------------------------------------------------;
data _null_;
    set trttotals;
    call symputx(cats("trt",treatment),trttotal);  /*Combine multiple values ??into a single string*/
run;
/*call symputx(name, value)*/
/*Stores the value into a macro variable named `name`.*/
/*Leading and trailing spaces are automatically removed.*/
/*Numeric values ??are automatically converted to character strings.*/
/*	`%let` can only be used for fixed values.*/
/*	The value of N here is calculated at runtime.*/
/*		SYM (Symbol)*/
/*		Refers to the macro symbol table.*/




*==============================================================================;
*```````````````get counts for table body;
*==============================================================================;
/* itt fas safe pp number by treatment groups by populations*/
proc sql;
   create table counts01 as
      select 1 as order, treatment, count(distinct usubjid) as count
      from adsl02

      where randfl="Y"
      group by treatment
 
 
      union all corr
 
      select 2 as order, treatment, count(distinct usubjid) as count
      from adsl02
      where fasfl="Y"
      group by treatment
 
      union all corr
 
      select 3 as order, treatment, count(distinct usubjid) as count
      from adsl02
      where saffl="Y"
      group by treatment
 
      union all corr
 
      select 4 as order, treatment, count(distinct usubjid) as count
      from adsl02
      where PPSFL="Y"
      group by treatment
      ;
quit;
/* order = 1*/
/* Used to indicate "Row 1: Randomized Analysis Set"*/
/*treatment*/
/* Grouped by treatment group (including Overall=4)*/
/*count(distinct usubjid)*/
/* Counts the number of unique subjects*/
/*where randfl="Y"*/
/* Only counts the randomized population*/
/*	Append the results of multiple SELECT statements directly.*/
/*	Do not remove duplicates (this is what you want).*/
/*	Align by column name. */




*==============================================================================;
*````````````````create dummy data and merge with actual counts;
*==============================================================================;
/* create a order variable*/
data dummy01;
    length label $200;
 
    order=1; label="Randomized Analysis Set"; output;
    order=2; label="Full Analysis Set"; output;
    order=3; label="Safety Analysis Set"; output;
    order=4; label="Per-protocol Analysis Set"; output;
run;
 
data dummy02;
   set dummy01;
 
   do treatment=&arm0.,&arm54.,&arm81.,&OVERALL.;
    output;
   end;
run;
 
proc sort data=dummy02;
   by order treatment;
   where  ;
run;

/*merge label and denominator*/
proc sort data=counts01;
   by order treatment;
   where  ;
run;
 
data counts02;
   merge dummy02(in=a)
         counts01(in=b);
   by order treatment;
 
   if a and not b then count=0;
run;
 



*==============================================================================;
*`````````````calculate percentages;
*==============================================================================;
/* in long format dataset*/
proc sort data=trttotals ;
   by treatment;
   where  ;
run;
 
proc sort data=counts02 ;
   by treatment;
   where  ;
run;
/*merge numeriator and denominator */
data counts03;
   merge counts02(in=a)
         trttotals(in=b);
   by treatment;
 
   if a;
run;
 
data counts04;
   set counts03;
 
   length cp $30;
 
   if trttotal>0 and count>0 then cp=strip(put(count,8.))||" ("||strip(put(count/trttotal*100,5.1))||")";
   else cp=strip(put(count,8.));
/*   calculate the percentage*/
run;
/*put(..., 5.1)*/
/*Percentage format:*/
/*Total width 5*/
/*1 decimal place */
/*	put(count, 3.)*/
/*	Converts the numeric value of `count` to a string.*/
/*	Format 3.:*/
/*	Right-aligned*/
/*	Maximum 3 digits*/
/*		Therefore, the process is:*/
/*		First, calculate*/
/*		Then, assemble*/
/*		Finally, display*/




*==============================================================================;
*restructure the data to present treatments as columns;
*==============================================================================;
/* restucture into wide format */
proc sort data=counts04;
   by order label;
   where  ;
run;
 
proc transpose data=counts04   out=counts05 prefix=trt  ;
   by order label;

   var cp;
/*   transpose to horizon*/
   id treatment;
/*   column names from there*/
   where  ;
run;
/*Convert the data from "long format (one treatment per row)"*/
/*to "wide format (one column per treatment)".*/
/*	The newly generated column names start with "trt".*/
/*	Each (order, label) combination ? outputs one line*/
/*	cp: Specifies the variable to be "expanded horizontally".*/
/*	ID treatment; Decision: Which variable the new column name will come from.*/




*==============================================================================;
*report table based on the proc template;
*==============================================================================;
%rtf_output_style_setup(
  protocol=XXX01,
  population=%str(Randomized Analysis Set),
  pgm_path=%str(C:\XXX01\PROGRAMS\DRAFT\TFLs\ZZZ.sas)
);

/* title */
title3 j=c "^S={foreground=blue fontweight=bold fontstyle=italic}Summary for Analysis Sets";
title4 j=c "^S={foreground=blue fontweight=bold fontstyle=italic}Randomized Analysis Set";


ods listing close;
ods rtf file="&outputpath.\ds_analysis_sets.rtf" style=styles.csgpool01;
/*Use the styles (fonts, borders, header lines, and other appearance settings) that you defined using `proc template`. */
/*After this statement, all PROC output will be directed to this RTF file until `ods rtf close;` is encountered.*/
 
proc report data = counts05 center 	headline headskip 	nowd	 split='~' 	missing 	style(report)=[just=center]
   style(header)=[just=center];
/* select variables to display*/
   column order label trt0 trt54 trt81 trt4 ;
/* define column*/
   define order/order noprint;
   define label/width=30 " "  style(column)=[cellwidth=1.5in protectspecialchars=off] 	style(header)=[just=left];
   define trt0/"Placebo" "(N=&trt0.)"   style(column)=[cellwidth=1.2in just=center] ;
   define trt54/"Low dose" "(N=&trt54.)"  style(column)=[cellwidth=1.2in just=center]   ;
   define trt81/"High dose" "(N=&trt81.)"  style(column)=[cellwidth=1.2in just=center]   ;
   define trt4/"Total"        "(N=&trt4.)"  style(column)=[cellwidth=1.2in just=center]   ;
 
run;
/*center: Centers the entire table.*/
/*headline: Draws a line below the table header (often causes duplicate lines in RTF + custom styles).*/
/*headskip: Adds a blank line between the header and the data.*/
/*nowd: Runs in non-interactive mode.*/
/*split='~': Wraps text in column headers when a '~' appears (not used in your current headers, but harmless to keep).*/
/*missing: Displays missing values ??(prevents empty values ??from being hidden).*/
/*style(report)=[just=center]: Centers the entire table (report).*/
/*style(header)=[just=center]: Centers all column headers by default.*/
/* */
/*	Specify the order of the output columns (column structure):*/
/*	column order label trt0 trt54 trt81 trt4;*/
/*Defining how each column is displayed (DEFINE statement)*/
/*		width=30: Traditional character width (in RTF, this is mainly controlled by cellwidth)*/
/*		" ": Column header set to blank (so the first column of the table header does not display text)*/
/*		style(column)=[cellwidth=1.5in ...]:*/
/*		Data cell width 1.5 inches*/
/*		protectspecialchars=off:*/
/*		Allows special characters/ODS control characters to take effect (for example, if you want to include ^S={} control formatting in the label later)*/
/*		style(header)=[just=left]:*/
/*		The header of this column is left-aligned (although it's blank, it's good practice to set it)*/
/*			Column header is in two lines:*/
/*			First line: Dose level 1*/
/*			Second line: (N=xxx), where xxx comes from the macro variable &trt0.*/
/*			cellwidth=1.2in: Column width is 1.2 inches*/
/*			just=center: Content in this column is centered */

ods rtf close;
ods listing;

title;
footnote;

%close_log;

 

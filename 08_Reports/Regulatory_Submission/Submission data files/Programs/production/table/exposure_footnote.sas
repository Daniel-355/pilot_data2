/**********************************************************************
 Program:    exposure.sas
 Purpose:    create a exposure table
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
 
proc format;
   value durcat
      low - 7 = "<7"
      7 - 14 = ">=7 to <14"
      14 - 28 = ">=14 to <28"
	   28 - 42 = ">=28 to <42"
      42 - high = ">=42"
	  . = "Missing"
;
run;

/*=========================================================
Read and process input datasets
=========================================================*/
data adsl01;
    set adam.adsl;      /*set permanent library*/
    where saffl="Y";
	pre_result=TRTEDT-TRTSDT;
pre_result_gr=put(pre_result,durcat.);
run;
 
/*=========================================================
Replicate rows to account the subjects under total column - using explicit output statements
=========================================================*/
data adsl02;
    set adsl01;
 
    treatment=trt01an;
    output;
 
    treatment=4;     /*total*/
    output;
run;
 
/*=========================================================
Get the treatment totals into a dataset and macro variables
=========================================================*/
 
/*----------------------------------------------------------
Create a dummy dataset containing a row for each treatment column to be displayed
----------------------------------------------------------*/
 
data dummy_trttotals;
    do treatment=0,54,81,4;
        output;
    end;
run;
 
/*----------------------------------------------------------
Get treatment totals based on actual data - using proc freq
----------------------------------------------------------*/
 
proc freq data=adsl02;
    tables  treatment  /out=trttotals01(rename=(count=trttotal) drop=percent);
run;
 
 
/*----------------------------------------------------------
Merge the dummy dataset containing all treatment rows with actual treatment totals dataset
----------------------------------------------------------*/
 proc sort data=dummy_trttotals;
 by treatment;
 run; 

data trttotals;
    merge dummy_trttotals(in=a) trttotals01(in=b);
    by treatment;
    if a and not b then trttotal=0;
run;
 
/*----------------------------------------------------------
````````````````Create macro variables to hold treatment totals - using call symputx in data step
----------------------------------------------------------*/
 
data _null_;
    set trttotals;
    call symputx(cats("trt",treatment),trttotal);
run;
 %put &trt54.; 
 
/*=========================================================
Processing for `````````````````continuous variables
=========================================================*/
 
 
/*=========================================================
Fetch all the analysis variables into a single variable using output statement
=========================================================*/
/*----------------------------------------------------------
`````````````Create the group variables to indicate the rows for each analysis variable
----------------------------------------------------------*/
 
data adsl03_numeric;
    set adsl02;
    length grouplabel $200;
 
    group=2;
    grouplabel="Duration (days)";      /*group2 position*/
    result=pre_result;
/*trdurn*/
    dp=0;
    output;
 
    group=3;
    grouplabel="Treatment Compliance (%)";       /*group3 position*/
    result=pre_result;
/*trcpl*/
    dp=1;
    output;
run;
 
/*proc contents data=adsl02 varnum;*/
/*run; */

/*=========================================================
Create a format for treatment levels - using proc format
=========================================================*/
/*proc format;*/
/*    value treatment*/
/*    0=1*/
/*    54=2*/
/*    81=3*/
/*    4=4*/
/*    ;*/
/*run;*/
 
/*=========================================================
Obtain the descriptive statistics for the analysis variable - using proc summary
=========================================================*/
/*----------------------------------------------------------
Completetypes option is used to 'Create all possible combinations of class variable values'<br>
Preloadfmt option 'specifies that all formats are preloaded for the class variables.'<br>
By statement is used to fetch the statistics within each group
----------------------------------------------------------*/
proc sort data=adsl03_numeric out=adsl04_numeric;
    by group grouplabel dp;
run;
 
proc summary data=adsl04_numeric nway completetypes;
    by group               grouplabel dp;                  /*same thing*/

    class treatment/preloadfmt;
    var  result;                  
    output out=stats01 n= nmiss= mean= std= min= q1= median= q3= max= /autoname;
/*    format treatment treatment.;*/
run;
 
/*=========================================================
``````````````````Process the statistics as per presentation requirements
=========================================================*/
data stats02;
    set stats01;
    length mean std q1 q3 min max nnmiss meanstd median q1q3 minmax $30;
 
    if dp gt 0 then do;
    asisf=cats(4+dp,".",dp);
    plusonef=cats(5+dp,".",dp+1);
    plustwof=cats(6+dp,".",dp+2);
    end;
    else do;
        asisf=cats("4.");
        plusonef="5.1";
        plustwof="6.2";
    end;
 
    *process individual statistics;
 
 
    if result_mean ne . then mean=putn(result_mean,plusonef);
 
    if result_stddev ne . then std=" ("||putn(result_stddev,plustwof)||")";
    else std=" ( - )";
 
    if result_median ne . then median=putn(result_median,plusonef);
    if result_q1 ne . then q1=putn(result_q1,plusonef);
    if result_q3 ne . then q3=putn(result_q3,plusonef);
    if result_min ne . then min=putn(result_min,asisf);
    if result_max ne . then max=putn(result_max,asisf);
 
    *create combined statistics;
    nnmiss=put(result_n,4.)||" ("||strip(put(result_nmiss,4.))||")";
    if result_n ne 0 then do;
        meanstd=trim(mean)||trim(std);
        q1q3=trim(q1)||","||trim(q3);
        minmax=trim(min)||","||trim(max);
    end;
run;
 
/*----------------------------------------------------------
Keep only the required variables - treatment and concatenated statistics
----------------------------------------------------------*/
data stats03;
    set stats02;
    keep group grouplabel treatment nnmiss meanstd q1q3 median minmax;
run;
 
/*=========================================================
```````````````````Restructure the statistics such that they appear as 'rows' - using proc transpose
=========================================================*/
proc sort data=stats03;
    by group grouplabel treatment;
run;
 
proc transpose data=stats03 out=stats04;
    by group grouplabel treatment;
    var nnmiss meanstd median q1q3 minmax;
run;
 
/*=========================================================
Create some supporting variables as ``````````````per sorting and presentation requirements: intord
=========================================================*/
data stats05;
    set stats04;
 
    _name_=upcase(_name_);
 
    length statistic $100;
 
    if _name_="NNMISS"  then do; intord=1; statistic="n (missing)"; end;
    if _name_="MEANSTD" then do; intord=2; statistic="Mean (SD)";   end;
    if _name_="MEDIAN"  then do; intord=3; statistic="Median";      end;
    if _name_="Q1Q3"    then do; intord=4; statistic="Q1, Q3"; end;
    if _name_="MINMAX"  then do; intord=5; statistic="Min, Max"; end;
run;
 
/*=========================================================
Restructure the data such that treatments appear as 'columns' - using proc transpose
=========================================================*/
 
proc sort data=stats05;
    by group grouplabel intord statistic;
run;
 
proc transpose data=stats05 out=stats06 prefix=trt;
    by group grouplabel intord statistic;
    var col1;
    id treatment;
run;
 
/*=========================================================
Create final dataset - keeping only required variables
=========================================================*/
 
data final_numeric;
    set stats06;
    keep group grouplabel intord statistic trt0 trt54  trt81 trt4;
run;
 


/*=========================================================
Processing for `````````````````````````categorical variables
=========================================================*/
 
/*=========================================================
Create some utility variables for smooth processing in the down-stream code
=========================================================*/
 
data adsl03_categorical;
    set adsl02;
 
 
    length statistic $100;
 
    group=1;
    if not missing(pre_result_gr) then statistic=pre_result_gr;
/*trdgr1*/
    else statistic="Missing";
 
    output;
run;
 
/*=========================================================
Obtain counts for the categorical variable - sex
=========================================================*/
proc freq data=adsl03_categorical noprint;
    tables group*treatment*statistic/out=counts01(drop=percent);           /*``````````````contingence table */
run;
 
/*=========================================================
Create a dummy dataset containing a row for each level and treatment
=========================================================*/
/*----------------------------------------------------------
Create a row for each level of the categorical variable - using output statements
----------------------------------------------------------*/
data dummy01;
    length grouplabel statistic $100;
 
    group=1; grouplabel="Duration (days)";
 
    intord=1;  statistic="<7";                     output;
    intord=2;  statistic=">=7 to <14";  output;
    intord=3;  statistic=">=14 to <28";                      output;
    intord=4;  statistic=">=28 to <42";               output;
    intord=5;  statistic=">=42";               output;
    intord=99; statistic="Missing";                    output;
run;
 
/*----------------------------------------------------------
Create a row for each treament for record present in dummy01 - using a do loop with output statement
----------------------------------------------------------*/
data dummy02;
    set dummy01;
    do treatment=0,54,81,4;
        output;
    end;
run;
 
/*=========================================================
Merge the dummy counts with actual counts
=========================================================*/
 
proc sort data=dummy02;
    by group treatment statistic;
run;
 
proc sort data=counts01;
    by group treatment statistic;
run;
 
data counts02;
    merge dummy02(in=a) counts01(in=b);
    by group treatment statistic;
    if a and not b then count=0;
run;
 
/*=========================================================
Calculate percentages
=========================================================*/
/*----------------------------------------------------------
Fetch treatment totals into the dataset containing counts
----------------------------------------------------------*/
proc sort data=trttotals;
    by treatment;
run;
 
proc sort data=counts02;
    by treatment;
run;
 
data counts03;
    merge counts02(in=a) trttotals(in=b);
    by treatment;
run;
 
/*----------------------------------------------------------
Create percentage variable and concatenate count and percentage into a single variable
----------------------------------------------------------*/
 
data counts04;
    set counts03;
 
    if trttotal ne 0 then percent=count/trttotal*100;
 
    length cp $30;
 
    if count ne 0 then do;
        if percent ne 100 then cp=put(count,3.)||" ("||strip(put(percent,5.1))||")";
        else cp=put(count,3.)||" ("||strip(put(percent,3.))||")";
    end;
    else do;
       cp=put(count,3.);
    end;
run;
 
/*=========================================================
Restructure the dataset such that treatments appear as columns - using proc transpose
=========================================================*/
 
proc sort data=counts04;
    by group grouplabel intord statistic;
run;
 
proc transpose data=counts04 out=counts05 prefix=trt;
    by group grouplabel intord statistic;
    var cp;
    id treatment;
run;
 
/*=========================================================
Create final dataset - keeping only required variables
=========================================================*/
 
data final_categorical;
    set counts05;
    keep group grouplabel intord statistic trt0 trt54 trt81 trt4;
run;
 
 

/*=========================================================
```````````````Combine categorical and numeric variable summaries
=========================================================*/
 
data final;
    set final_numeric final_categorical;
run;
 
proc sort data=final;
    by group grouplabel intord;
run;
 
 

/*=========================================================
``````````````Report generation
=========================================================*/
%rtf_output_style_setup(
  protocol=XXX01,
  population=%str(Safety Analysis Set),
  pgm_path=%str(C:\XXX01\PROGRAMS\DRAFT\TFLs\ZZZ.sas)
);  
 

title3  "^S={foreground=blue fontweight=bold fontstyle=italic}Study Drug Exposure";
title4   "^S={foreground=blue fontweight=bold fontstyle=italic}Safety Analysis Set";

footnote5  j=l "Percentages are calculated based on the number of subjects in each treatment.";

ods listing close;
ods rtf file="&outputpath.\exposure.rtf" style=csgpool01;
 
 
proc report data = final center headline headskip nowd split='~' missing style(report)=[just=center]
   style(header)=[just=center];
 
   column group grouplabel intord statistic trt0 trt54 trt81 trt4 ;
 
   define group/order noprint;
   define intord /order noprint;
 
   define grouplabel/width=30 "Variable" order style(column)=[cellwidth=1.5in protectspecialchars=off] style(header)=[just=left];
   define statistic/width=30 "Statistic" style(column)=[cellwidth=1.5in protectspecialchars=off] style(header)=[just=left];
 
   define trt0/"Placebo" "(N=&trt0.)"   style(column)=[cellwidth=1.2in just=center] ;
   define trt54/"Low dose" "(N=&trt54.)"  style(column)=[cellwidth=1.2in just=center]   ;
   define trt81/"High dose" "(N=&trt81.)"  style(column)=[cellwidth=1.2in just=center]   ;
   define trt4/"Total"        "(N=&trt4.)"  style(column)=[cellwidth=1.2in just=center]   ;
 
   compute after group;
     line @1 "";
   endcomp;
run;
 
 
ods rtf close;
ods listing;

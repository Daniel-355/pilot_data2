/**********************************************************************
 Program:    dm_list.sas
 Purpose:    create a dm list
 Author:     Daniel
 Date:       2026-01-03
**********************************************************************/


/*====================*/
/* include _setup.sas and /*open log*/  */
/*====================*/;
%let SETUP_PATH=%str(C:\Users\hed2\Downloads\Clinical_Trial_2025_DrugA_Phase3\08_Reports\Regulatory_Submission\Submission data files\_setup.sas);
%include "&SETUP_PATH";

%let PGNAME=dm_list;
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
Read input data
=========================================================*/
 
data adsl01;       /*use adam datasets*/
   set adam.adsl;
   where ITTFL="Y";     /*randfl=ITTFL*/
run;
 
/*=========================================================
Create columns as per listing requirement
=========================================================*/
 
data list01;         /*create variables to showcase*/
   set adsl01;
 
   col1="Investigator Site = "||strip(siteid);  
   col2=usubjid;

   col3=trt01p;  

   if age ne . then col4=strip(put(age,best.));
   else col4="-";

   if sex ne "" then col5=sex;
   else col5="-";

   if arace ne "" then col6=arace;
   else arace="-";

   if raceoth ne "" then col7=raceoth;
   else col7="-";
 
   if weightbl ne . then col8=strip(put(weightbl,best.));
   else col8="-";

   if heightbl ne . then col9=strip(put(heightbl,best.));
   else col9="-";
 
run;
 
/*=========================================================
Sort the records as per listing requirement and create a sequence variable
=========================================================*/
 
proc sort data=list01;
   by siteid usubjid;
run;
 
data list02;
   set list01;
   by siteid usubjid;   /*sort by siteid usubjid */
   listseq=_n_;
run;
 
 
/*=========================================================
Generate Report
=========================================================*/
 
%rtf_output_style_setup(
  protocol=XXX01,
  population=%str(Randomized Analysis Set),
  pgm_path=%str(C:\XXX01\PROGRAMS\DRAFT\TFLs\ZZZ.sas)
); 
 
 
title3 "^S={foreground=blue fontweight=bold fontstyle=italic}Demographic Characteristics";
title4 "^S={foreground=blue fontweight=bold fontstyle=italic}Randomized Analysis Set";

 
ods listing close;
ods rtf file="&outputpath.\dm_list.rtf" style=csgpool01;
 
proc report data=list02 nowd missing
   style(report)={just=center}
   style(column)={just=left}
   style(header)={just=left};
 
   column siteid col1 usubjid col2 col3 col4 col5 col6 col7 col8 col9;
 
   define siteid/order order=data noprint;             
   define usubjid/order order=data noprint;

   define col1/order order=data noprint;           /*noprint*/
 
   define col2/"Subject ID" style(column)={cellwidth=0.75in};
   define col3/"Treatment" "group" style(column)={cellwidth=1in};
   define col4/"Age (years)" style(column)={cellwidth=0.75in};
   define col5/"Sex" style(column)={cellwidth=0.5in};
   define col6/"Race" style(column)={cellwidth=1in};
   define col7/"Race" "(Other)" style(column)={cellwidth=1in};
   define col8/"Weight (kg)" style(column)={cellwidth=0.75in};
   define col9/"Height (cm)" style(column)={cellwidth=0.75in};
 
   compute after siteid;
      line @1 " ";
   endcomp;
 
   compute before col1;
      line @1 col1 $150.;
      line @1 " ";
   endcomp;
 
run;
ods rtf close;
ods listing;
 
 

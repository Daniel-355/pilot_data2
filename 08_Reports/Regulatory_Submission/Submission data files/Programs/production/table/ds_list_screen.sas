/**********************************************************************
 Program:    ds_list.sas
 Purpose:    create a ds list
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
 
/*``````````````````screening */
/*=========================================================
Read input data
=========================================================*/
 
data adsl01;
   set adam.adsl;
   where DCREASCD = "I/E Not Met";    
run;
/* proc contents data= adsl01 varnum;run; */

/*=========================================================
Create columns as per listing requirement
=========================================================*/
 
data list01;
   set adsl01;
 
   length siteidnam $100 agec $20;

   siteidnam="Investigator site = "|| strip(siteid)||","||strip(sitenam);
   if age ne . then agec=strip(put(age,3.));
   else agec="-";
 
   if sex="" then sex="-";
   if race="" then race="-";
 
run;
 
 
/*=========================================================
Sort the data as per listing requirement and create a variable to hold sequence
=========================================================*/
 
proc sort data=list01;
   by siteid usubjid;
run;
 
data list02;
   set list01;
   by siteid usubjid;
   listseq=_n_;
run;
 
/*=========================================================
Generate Report
=========================================================*/
 
%rtf_output_style_setup(
  protocol=XXX01,
  population=%str(Screen Failure Subjects),
  pgm_path=%str(C:\XXX01\PROGRAMS\DRAFT\TFLs\ZZZ.sas)
); 

 
title3 "^S={foreground=blue fontweight=bold fontstyle=italic}Screen Failures";
title4 "^S={foreground=blue fontweight=bold fontstyle=italic}Screen Failure Subjects";

ods listing close;
ods rtf file="&outputpath.\ds_screen.rtf" style=csgpool01;
 
/*proc contents data=list02 varnum;run;*/

proc report data=list02 nowd missing
   style(report)={just=center}
   style(header)={just=left}
   style(column)={just=left};
   columns siteid siteidnam usubjid agec sex race DCREASCD;
 
   define siteid/order order=data noprint;     
   define siteidnam/order order=data noprint;
 
   define usubjid/"Subject ID" style(column)={cellwidth=1in};
   define agec/"Age (unit)" style(column)={cellwidth=0.75in};
   define sex/"Sex" style(column)={cellwidth=0.5in};
   define race/"Race" style(column)={cellwidth=2in};
   define DCREASCD/"Reason for Discontinuation" style(column)={cellwidth=2in};
 
   compute after siteid;
      line @1 " ";
   endcomp;
 
   compute before siteidnam;
      line @1 siteidnam $100.;
      line @1 " ";
   endcomp;
run;
ods rtf close;
ods listing;
 
/*%convert_rtf_to_pdf_vbscript;*/
 
 

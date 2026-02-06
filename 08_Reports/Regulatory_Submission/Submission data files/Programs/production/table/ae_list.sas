/**********************************************************************
 Program:    ae_list.sas
 Purpose:    create a ae list
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
 
data adae01;
   set adam.adae;
run;
 
data adsl01;
   set adam.adsl;
run;
 
/*=========================================================
Merge adsl and adae datasets
=========================================================*/
 
data adae02;
   merge adae01(in=a) adsl01(in=b);
   by usubjid;
   if a and b;
run;
 
/*=========================================================
Create columns as per listing requirement
=========================================================*/
 
data list01;
 
   set adae02;
   length col1 $200;
 
   col1_ord=trt01an;
   col1="(*ESC*)S={borderbottomcolor=black borderbottomwidth=1} "||strip(trt01a);   /*treatment names, no showcase */
 
   *------------------------------------------------------------------------------;
   *SARS - col2;
   *------------------------------------------------------------------------------;
   if age ne . then agec=cats("{\line}",age);      /*agec text ; missing = dash*/
   else agec="{\line}-";
 
   if race ne "AMERICAN INDIAN OR ALASKAN NATIVE" then races=first(race); 
   else if race="" then races="-";
   else races="I";       /*races text */
 
   if sex="" then sex="-";    /*  missing = dash*/
 
   col2_ord=usubjid;
   col2=catx("/",usubjid,agec,races,sex);    /*combine usubjid,agec,races,sex*/  
 
   *------------------------------------------------------------------------------;
   *SOC-PT-TERM - col3;
   *------------------------------------------------------------------------------;
 
   length aebodsys_ aedecod_ aeterm_ $200;
 
   if aebodsys="" then aebodsys_="-";
   else aebodsys_=aebodsys; 
 
   if aedecod="" then aedecod_="-";
   else aedecod_=aedecod;
 
   aedecod_="\pnhang\par\li200 "||strip(aedecod_);
 
   if aeterm="" then aeterm="-";
   else aeterm_=aeterm;
 
   aeterm_="\pnhang\par\li400 "||strip(aeterm_);
 
   col3=catx('/',aebodsys_,aedecod_,aeterm_);    /*soc pt and verbatim, combine  */  
 
   *------------------------------------------------------------------------------;
   *dates - col4;
   *------------------------------------------------------------------------------;
 
   length aestdtc_ aestdy_ aeendtc_ aeendy_ start end $200;
 
   if aestdtc="" then aestdtc_="-";
   else aestdtc_=aestdtc;
 
   if aestdy ne . then aestdy_=cats("(",aestdy,")");
   else aestdy_="(-)";
 
   if aeendtc="" then aeendtc_="{\line} Ongoing";
   else aeendtc_="{\line}"||strip(aeendtc);
 
   if aeendtc ne "" and aeendy=. then aeendy_="(-)";
   else aeendy_=cats("(",aeendy,")");
 
   start=strip(aestdtc_)||" "||strip(aestdy_);
   end=strip(aeendtc_)||" "||strip(aeendy_);
 
   col4=catx("/",start,end);            /*date combine  */  
   *------------------------------------------------------------------------------;
   *sev-col5, out-col6, relation-col7 action-col8;
   *------------------------------------------------------------------------------;
 
   length col5 col6 col7 col8 $200;
 
   if aesev ne "" then col5=propcase(aesev);
   else col5="-";            /*severity  */  
 
   if aeout="RECOVERED/RESOLVED" then col6="1";
   else if aeout="RECOVERING/RESOLVING" then col6="2";
   else if aeout="NOT RECOVERED/NOT RESOLVED" then col6="3";
   else if aeout="RECOVERED/RESOLVED WITH SEQUEALE" then col6="4";
   else if aeout="FATAL" then col6="5";
   else if aeout="UNKNOWN" then col6="6";
   else col6="-";          /*ae outcome  */  
 
   col7=propcase(aerel);    /*ae relative  */  
 
   if aeacn="DOSE REDUCED" then col8="1";
   else if aeacn="DRUG INTERRUPTED" then col8="2";
   else if aeacn="DRUG WITHDRAWN" then col8="3";
   else col8="-";
 
   blank="";              /*ae action  */  
run;
 
 
proc freq data= list01  ;
    tables  aeacn  /list missing out=_uniquevalues01;
    where 1=1;
run;
 
 
/*=========================================================
Final sort as per listing requirement
=========================================================*/
 
proc sort data=list01;
   by trt01an usubjid    aestdtc aeendtc         aebodsys aedecod aeterm;    /*sort by these variables */
run;
 
data list02;
   set list01;
   seq=_n_;
run;
 
/*=========================================================
Generate report
=========================================================*/
 
%rtf_output_style_setup(
  protocol=XXX01,
  population=%str(Safety Analysis Set),
  pgm_path=%str(C:\XXX01\PROGRAMS\DRAFT\TFLs\ZZZ.sas)
); 
 

title3 "^S={foreground=blue fontweight=bold fontstyle=italic}Adverse Events";
title4 "^S={foreground=blue fontweight=bold fontstyle=italic}Safety Analysis Set";

footnote5 j=l "^{super a}: Outcome is AE outcome.";
  
ods listing close;
ods rtf file="&outputpath.\ae_list.rtf" style=csgpool01;
 
proc report data=list02 missing  split="~"
   style(report)={just=center }
   style(column)={just=left protectspecialchars=off}
   style(header)={just=left protectspecialchars=off};
 
   column trt01an col1 usubjid col2 aebodsys aedecod aeterm blank col3 blank col4 col5 col6 col7 col8;
 
   define trt01an/order order=data noprint;
   define col1/noprint;
   define usubjid/order order=data noprint;
   define aebodsys/order order=data noprint;
   define aedecod/order order=data noprint;
   define aeterm/order order=data noprint;
 
   define col2/"Subject ID/" "Age/Race/Sex" style(column)={cellwidth=0.8in};
   define col3/"MedDRA SOC/" "  Preferred Term/" "    Verbatim Term/" style(column)={cellwidth=2in just=left} style(header)={just=left asis=on};
   define col4/"Start Date (Day)/" "Stop Date (Day)" style(column)={cellwidth=1.1in};
   define col5/"Severity" style(column)={cellwidth=0.75in};
   define col6/"Outcome{\super a}" style(column)={cellwidth=0.75in};
   define col7/"Related" style(column)={cellwidth=0.75in};
   define col8/"Action{\super b}" style(column)={cellwidth=0.75in};
   define blank/" " style(column)={cellwidth=0.1};
 
   break after trt01an/page;


   compute after aeterm;
      line @1 "";
   endcomp;
/* After each value of the grouping variable `aeterm`, a blank line is forcibly output to improve readability and separate different AE records.*/
 compute before _page_;
   line @1 "^S={
	  borderwidth=0 borderbottomwidth=0 bordertopwidth=0 borderleftwidth=0 borderrightwidth=0       
	  bordertopstyle=none
      borderleftstyle=none
      borderrightstyle=none

      bordertopcolor=white
      borderleftcolor=white
      borderrightcolor=white}" col1 $150.;
endcomp;
/*At the beginning of each page, output a line of text above the table, using the content from variable `col1`, starting from column 1 with a display width of 150.*/
run;
ods rtf close;
ods listing;
/*%convert_rtf_to_pdf_vbscript;*/
/*Therefore, for production environments, it's highly recommended to use ODS format exclusively, as it's the most stable across different formats.*/

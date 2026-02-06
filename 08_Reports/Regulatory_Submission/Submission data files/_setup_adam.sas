/**************************************************************************
File:        _setup_adam.sas
Purpose:     Project-level setup for ADaM creation:
             - Determine project root
             - Define standard folders
             - Assign librefs (SDTM/ADaM/DERIVED/FORMATS/OUTPUT)
             - Set core options + SASAUTOS
             - Provide log header + open/close log helpers
Owner:       Clinical Programming
Created:     2026-01-25
Notes:       Keep this file minimal and reusable across ADaM programs.
**************************************************************************/

/*--------------------------------------------------------------
0) Core options (adjust per SOP)
--------------------------------------------------------------*/
options
  nodate nonumber
  validvarname=upcase
  mprint mlogic symbolgen  /* remove if too noisy */
  msglevel=i
;

/* Use ODS escape sequences only if needed */
ods escapechar='^';

/*--------------------------------------------------------------
1) Helper macros (small + defensive)
--------------------------------------------------------------*/
%macro log_section(msg);
  %put NOTE- ============================================================;
  %put NOTE- &msg;
  %put NOTE- ============================================================;
%mend;

%macro assert_exists(path, type=DIR);
  %local exists;
  %let exists=%sysfunc(fileexist(&path));

  %if &exists=0 %then %do;
    %put ERROR: Expected &type does not exist: &path;
    %abort cancel;
  %end;
%mend;

/* Create a directory if missing (works on Windows/Linux) */
%macro ensure_dir(dir);
  %if not %length(&dir) %then %do;
    %put ERROR: ensure_dir(): DIR is blank.;
    %abort cancel;
  %end;

  %if %sysfunc(fileexist(&dir))=0 %then %do;
    %local _norm _pos _parent _leaf _rc;

    %let _norm=%sysfunc(tranwrd(&dir,%str(\),%str(/)));
    %let _pos=%sysfunc(findc(&_norm,%str(/),-200));

    %if &_pos > 1 %then %do;
      %let _parent=%substr(&_norm,1,%eval(&_pos-1));
      %let _leaf=%substr(&_norm,%eval(&_pos+1));

      %if %sysfunc(fileexist(&_parent))=0 %then %do;
        %put ERROR: Parent directory does not exist: &_parent;
        %abort cancel;
      %end;

      %let _rc=%sysfunc(dcreate(&_leaf,&_parent));
      %if &_rc=0 %then %do;
        %put ERROR: Failed to create directory: &dir;
        %abort cancel;
      %end;

      %put NOTE: Created directory: &dir;
    %end;
    %else %do;
      %put ERROR: Cannot parse directory path: &dir;
      %abort cancel;
    %end;
  %end;
%mend;

/*--------------------------------------------------------------
2) Determine project ROOT (portable)
   Priority:
   A) &ROOT passed via -set ROOT
   B) Environment variable PROJECT_ROOT
   C) Derive from SETUP_PATH (full path to this file)
--------------------------------------------------------------*/
%macro set_root;
  %global ROOT;

  /* A) External -set ROOT ... */
  %if %symexist(ROOT) and %length(&ROOT) %then %do;
    %let ROOT=%sysfunc(dequote(&ROOT));
    %return;
  %end;

  /* B) Environment variable */
  %let ROOT=%sysget(PROJECT_ROOT);
  %if %length(&ROOT) %then %do;
    %let ROOT=%sysfunc(dequote(&ROOT));
    %return;
  %end;

  /* C) Derive ROOT from SETUP_PATH */
  %if %symexist(SETUP_PATH) and %length(&SETUP_PATH) %then %do;
    %local _p _pos;
    %let _p=%sysfunc(tranwrd(%sysfunc(dequote(&SETUP_PATH)),%str(\),%str(/)));
    %let _pos=%sysfunc(findc(&_p,%str(/),-200));

    %if &_pos > 1 %then %do;
      %let ROOT=%substr(&_p,1,%eval(&_pos-1));
      %return;
    %end;
    %else %do;
      %put ERROR: SETUP_PATH is not a valid full file path: &SETUP_PATH;
      %abort cancel;
    %end;
  %end;

  %put ERROR: Unable to determine ROOT. Pass -set ROOT <project_root> or set PROJECT_ROOT or define SETUP_PATH.;
  %abort cancel;
%mend;

%set_root;

/* Normalize slashes */
%let ROOT=%sysfunc(tranwrd(&ROOT,%str(\),%str(/)));

/* Validate ROOT directory */
%assert_exists(&ROOT, type=DIR);

/*--------------------------------------------------------------
3) Standard project subfolders (edit to match your repo)
   Minimal ADaM-oriented structure:
     Data/SDTM, Data/ADaM, Data/DERIVED (work/intermediate)
--------------------------------------------------------------*/
%global DIR_PROG DIR_MACRO DIR_DATA DIR_SDTM DIR_ADAM DIR_DERIVED
        DIR_FMT DIR_OUTPUT DIR_LOG DIR_QC;

%let DIR_PROG    =&ROOT./Programs;
%let DIR_MACRO   =&ROOT./Programs/macro;

%let DIR_DATA    =&ROOT./Data;
%let DIR_SDTM    =&ROOT./Data/SDTM;
%let DIR_ADAM    =&ROOT./Data/ADaM/create_dataset;
%let DIR_DERIVED =&ROOT./Data/DERIVED;

%let DIR_FMT     =&ROOT./Formats;

%let DIR_OUTPUT  =&ROOT./Outputs;
%let DIR_LOG     =&ROOT./Logs;
%let DIR_QC      =&ROOT./QC;

/* Ensure writeable/output dirs exist */
%ensure_dir(&DIR_ADAM);
%ensure_dir(&DIR_DERIVED);
%ensure_dir(&DIR_LOG);
%ensure_dir(&DIR_QC);

/*--------------------------------------------------------------
4) Assign LIBNAMEs
   - sdtm:     source SDTM
   - adam:     final ADaM datasets
   - deriv:    intermediate derived datasets
   - fmt:      formats (optional)
--------------------------------------------------------------*/
libname sdtm  "&DIR_SDTM";
libname adam  "&DIR_ADAM";
libname deriv "&DIR_DERIVED";

/* Formats library is optional */
%if %length(&DIR_FMT) and %sysfunc(fileexist(&DIR_FMT)) %then %do;
  libname fmt "&DIR_FMT";
  options fmtsearch=(fmt work);
%end;

/* Optional: outputs location for listings/tables etc. */
libname out "&DIR_OUTPUT";

/*--------------------------------------------------------------
5) Add macro search path (SASAUTOS)
--------------------------------------------------------------*/
options sasautos=("&DIR_MACRO" sasautos);

/*--------------------------------------------------------------
6) Standard log header (audit-friendly)
--------------------------------------------------------------*/
%log_section(ADaM Project Setup);

%put NOTE: ROOT          = &ROOT;
%put NOTE: DIR_SDTM      = &DIR_SDTM;
%put NOTE: DIR_ADAM      = &DIR_ADAM;
%put NOTE: DIR_DERIVED   = &DIR_DERIVED;
%put NOTE: DIR_MACRO     = &DIR_MACRO;
%put NOTE: DIR_LOG       = &DIR_LOG;
%put NOTE: DIR_QC        = &DIR_QC;

%put NOTE: SYSUSERID     = &sysuserid;
%put NOTE: SYSHOSTNAME   = &syshostname;
%put NOTE: SYSVLONG      = &sysvlong;
%put NOTE: SYSENCODING   = &sysencoding;
%put NOTE: SYSSCP        = &sysscp;
%put NOTE: RUN_DATETIME  = %sysfunc(datetime(),E8601DT19.);

/*--------------------------------------------------------------
7) Optional: program-specific log routing
   Usage:
     %let PGNAME=adam_adsl;
     %open_log(&PGNAME);
     ... program ...
     %close_log;
--------------------------------------------------------------*/
%macro open_log(pgname);
  %local logf;

  %if not %length(&pgname) %then %do;
    %put ERROR: open_log(): PGNAME is blank. Define %nrstr(%%let PGNAME=...) before calling open_log.;
    %abort cancel;
  %end;

  %let logf=&DIR_LOG./&pgname..log;
  proc printto log="&logf" new; run;
  %put NOTE: Writing log to &logf;
%mend;

%macro close_log;
  proc printto; run;
%mend;

/* End of _setup_adam.sas */


proc format;
        value _0n1y 0 = 'N'   /*no need to ifelse */
                    1 = 'Y'
        ;                    
        value avisitn 1 = '3'
                      2 = '6'
        ;                      
        value popfl 0 - high = 'Y'  /*0 to high is yes*/
                    other = 'N'
        ;                    
        value $trt01pn  'Active' = '1'   /*captial sensitive*/
                        'Placebo'             = '0'
        ;
        value agegr1n 0 - 54 = "1"
                      55-high= "2"
        ;                      
        value agegr1_ 1 = "<55 YEARS"
                      2 = ">=55 YEARS"
        ;                      
        value $aereln  'not'        = '0'
                       'possibly'   = '1'
                       'probably'   = '2'
        ;
        value $aesevn  'mild'               = '1'
                       'moderate'           = '2'
                       'severe'             = '3'
        ;                                              
        value relgr1n 0 = 'NOT RELATED'
                      1 = 'RELATED'
        ;                       
        value evntdesc 0 = 'PAIN RELIEF'
                       1 = 'PAIN WORSENING PRIOR TO RELIEF'
                       2 = 'PAIN ADVERSE EVENT PRIOR TO RELIEF'
                       3 = 'COMPLETED STUDY PRIOR TO RELIEF'
        ;                    
run;

/**************************************************************************
File:        _setup_sdtm.sas
Purpose:     Project-level setup for SDTM creation:
             - Determine project root
             - Define standard folders
             - Assign librefs (RAW/SDTM/DERIVED/FORMATS/OUTPUT)
             - Set core options + SASAUTOS
             - Provide log header + open/close log helpers
Owner:       Clinical Programming
Created:     2026-01-26
Notes:       Keep this file minimal and reusable across SDTM programs.
**************************************************************************/

/*--------------------------------------------------------------
0) Core options (adjust per SOP)
--------------------------------------------------------------*/
options
  nodate nonumber
  validvarname=upcase
  mprint mlogic symbolgen     /* remove if too noisy */
  msglevel=i
;

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

/* Create a directory if missing (works on Windows/Linux). Parent must exist. */
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
   Minimal SDTM-oriented structure:
     Data/RAW (optional), Data/SDTM (final), Data/SDTM/DERIVED (intermediate)
--------------------------------------------------------------*/
%global DIR_PROG DIR_MACRO DIR_DATA DIR_RAW DIR_SDTM DIR_SDTMDER
        DIR_FMT DIR_OUTPUT DIR_LOG DIR_QC;

%let DIR_PROG    =&ROOT./Programs;
%let DIR_MACRO   =&ROOT./Programs/macro;

%let DIR_DATA    =&ROOT./Data;
%let DIR_RAW     =&ROOT./Data/RAW;            /* optional: source/raw extracts */
%let DIR_SDTM    =&ROOT./Data/SDTM/create_dataset;           /* final SDTM */
%let DIR_SDTMDER =&ROOT./Data/SDTM/DERIVED;   /* intermediate SDTM build */

%let DIR_FMT     =&ROOT./Formats;

%let DIR_OUTPUT  =&ROOT./Outputs;
%let DIR_LOG     =&ROOT./Logs;
%let DIR_QC      =&ROOT./QC;

/* Ensure writeable/output dirs exist */
%ensure_dir(&DIR_SDTM);
%ensure_dir(&DIR_SDTMDER);
%ensure_dir(&DIR_LOG);
%ensure_dir(&DIR_QC);

/*--------------------------------------------------------------
4) Assign LIBNAMEs
   - raw:     optional source/raw extracts (if folder exists)
   - sdtm:    final SDTM datasets
   - sdtmder: intermediate SDTM datasets
   - fmt:     formats (optional)
--------------------------------------------------------------*/
%if %sysfunc(fileexist(&DIR_RAW)) %then %do;
  libname raw "&DIR_RAW";
%end;

libname sdtm    "&DIR_SDTM";
libname sdtmder "&DIR_SDTMDER";

/* Formats library is optional */
%if %length(&DIR_FMT) and %sysfunc(fileexist(&DIR_FMT)) %then %do;
  libname fmt "&DIR_FMT";
  options fmtsearch=(fmt work);
%end;

/* Optional: outputs location for listings/checks etc. */
libname out "&DIR_OUTPUT";

/*--------------------------------------------------------------
5) Add macro search path (SASAUTOS)
--------------------------------------------------------------*/
options sasautos=("&DIR_MACRO" sasautos);

/*--------------------------------------------------------------
6) Standard log header (audit-friendly)
--------------------------------------------------------------*/
%log_section(SDTM Project Setup);

%put NOTE: ROOT          = &ROOT;
%put NOTE: DIR_RAW       = &DIR_RAW;
%put NOTE: DIR_SDTM      = &DIR_SDTM;
%put NOTE: DIR_SDTMDER   = &DIR_SDTMDER;
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


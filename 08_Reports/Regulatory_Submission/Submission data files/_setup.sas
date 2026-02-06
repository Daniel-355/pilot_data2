/**************************************************************************
File:        _setup.sas
Purpose:     Project-level setup:   project root, subfolders, paths, librefs, options, common macros, sasauto search macro, set log header 
Owner:       Project Programming  
Created:     2026-01-06
Notes:       
**************************************************************************/

/*--------------------------------------------------------------
0) Basic options (adjust per SOP)
--------------------------------------------------------------*/
options
  nodate nonumber
  validvarname=upcase
;

/* ODS escape char (if your tables use ESC sequences) */
ods escapechar='^';

/*--------------------------------------------------------------
1) Helper macros
--------------------------------------------------------------*/
%macro log_section(msg);
  %put NOTE- ============================================================;
  %put NOTE- &msg;
  %put NOTE- ============================================================;
%mend;

%macro assert_exists(path, type=FILE);
  %local exists;
  %if %upcase(&type)=FILE %then %let exists=%sysfunc(fileexist(&path));
  %else %if %upcase(&type)=DIR %then %let exists=%sysfunc(fileexist(&path));
  %else %let exists=0;

  %if &exists=0 %then %do;
    %put ERROR: Expected &type does not exist: &path;
    %abort cancel;
  %end;
%mend;

/* Create a directory if missing (Windows or Linux). */
%macro ensure_dir(dir);
  /* *** MOD:  */
  %if not %length(&dir) %then %do;
    %put ERROR: ensure_dir(): DIR is blank.;
    %abort cancel;
  %end;

  %if %sysfunc(fileexist(&dir))=0 %then %do;
    %local _leaf _parent _pos _norm;

    /* *** MOD:  */
    %let _norm=%sysfunc(tranwrd(&dir,%str(\),%str(/)));

    /* *** MOD:  */
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
   A) &ROOT passed in by launcher (recommended)
   B) Environment variable PROJECT_ROOT (optional)
   C) Derive from SETUP_PATH (recommended for local/dev)
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

    /* *** MOD:  */
    /* *** MOD: SETUP_PATH  */
    %let _p=%sysfunc(tranwrd(%sysfunc(dequote(&SETUP_PATH)),%str(\),%str(/)));

    /* _setup.sas  */
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

/* Validate root */
%assert_exists(&ROOT, type=DIR);

/*--------------------------------------------------------------
3) Define standard project subfolders (edit to match your repo)
--------------------------------------------------------------*/
%global DIR_PROG DIR_MACRO DIR_INPUT DIR_ADAM DIR_TLFOUT DIR_QC DIR_LOG;

%let DIR_PROG   =&ROOT./Programs;
%let DIR_MACRO  =&ROOT./Programs/macro;
%let DIR_INPUT  =&ROOT./Data;
%let DIR_ADAM   =&ROOT./Data/ADaM;
%let DIR_TLFOUT =&ROOT./Outputs/Table;
%let DIR_QC     =&ROOT./QC;
%let DIR_LOG    =&ROOT./Logs;

/* Ensure common output dirs exist */
%ensure_dir(&DIR_TLFOUT);
%ensure_dir(&DIR_LOG);

%ensure_dir(&DIR_QC); /*check whether folder exist or not then create it*/

/*--------------------------------------------------------------
4) Assign LIBNAMEs
--------------------------------------------------------------*/
libname proj   "&ROOT";
libname adam   "&DIR_ADAM";
libname outtfl "&DIR_TLFOUT";

/* Optional: formats library */
%global DIR_FMT;
%let DIR_FMT=&ROOT./Formats;

/* *** MOD: `%length(&DIR_FMT)` is the first line of defense in defensive programming. */
%if %length(&DIR_FMT) and %sysfunc(fileexist(&DIR_FMT)) %then %do;
  libname fmt "&DIR_FMT";
  options fmtsearch=(fmt work);
%end;

/*--------------------------------------------------------------
5) Add macro search path (SASAUTOS)
--------------------------------------------------------------*/
options sasautos=("&DIR_MACRO" sasautos);

/*--------------------------------------------------------------
6) Standard log header (audit-friendly)
--------------------------------------------------------------*/
%log_section(Project Setup);

%put NOTE: ROOT          = &ROOT;
%put NOTE: DIR_PROG      = &DIR_PROG;
%put NOTE: DIR_ADAM      = &DIR_ADAM;
%put NOTE: DIR_TLFOUT    = &DIR_TLFOUT;
%put NOTE: DIR_LOG       = &DIR_LOG;

%put NOTE: SYSUSERID     = &sysuserid;
%put NOTE: SYSHOSTNAME   = &syshostname;
%put NOTE: SYSVLONG      = &sysvlong;
%put NOTE: SYSENCODING   = &sysencoding;
%put NOTE: SYSSCP        = &sysscp;

%put NOTE: RUN_DATETIME  = %sysfunc(datetime(),E8601DT19.);

/*--------------------------------------------------------------
7) Optional: open/close program-specific log file
--------------------------------------------------------------*/
%macro open_log(pgname);
  %local logf;

  /* *** MOD:  */
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


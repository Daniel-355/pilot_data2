
*==============================================================================;
*set up output template style;
*==============================================================================;

%macro rtf_output_style_setup(
    protocol=XXX01,
    population=YYY,

    footnote_text=%str(Copyright @ DH),

    pgm_path=,

    style_name=csgpool01,

    orientation=landscape,
/*    clear_tf=Y*/
);

  %local run_dt _pgm_path;

  /* output format */
  options orientation=&orientation nodate nonumber nobyline;
  ods escapechar='^';

  /* define style */
  proc template;
    define style styles.&style_name;
      parent = styles.rtf;

      style fonts /
        'TitleFont2'      = ("Courier New", 9pt, bold)
        'TitleFont'       = ("Courier New", 9pt, bold)
        'StrongFont'      = ("Courier New", 9pt, bold)
        'EmphasisFont'    = ("Courier New", 9pt, italic)
        'DocFont'         = ("Courier New", 9pt)
        'FixedFont'       = ("Courier New", 9pt)
        'BatchFixedFont'  = ("Courier New", 9pt)
	'HeadingFont'       = ("Courier New", 9pt, bold)
	'FixedStrongFont'   = ("Courier New", 9pt, bold)
	'FixedEmphasisFont' = ("Courier New", 9pt, italic);

      style table /
        frame=void
        rules=none
        cellspacing=0pt
        cellpadding=1pt
        borderwidth=0pt
        backgroundcolor=white;

      /* column headers: single underline only */
      style header /
        backgroundcolor=white
        foreground=black
        fontweight=bold
        bordertopwidth=0pt
        borderleftwidth=0pt
        borderrightwidth=0pt
        borderbottomwidth=0.75pt
        borderbottomcolor=black;

      style data /
        backgroundcolor=white
        foreground=black
        borderwidth=0pt;

      style rowheader /
        backgroundcolor=white
        foreground=black
        borderwidth=0pt;
    end;
  run;
  quit;

  /* run datetime (audit-friendly) */
  %let run_dt=%sysfunc(datetime(),E8601DT19.);

  /* program path in footnote (optional) */
  %if %length(&pgm_path) %then %let _pgm_path=&pgm_path;
  %else %let _pgm_path=%sysget(SAS_EXECFILEPATH);


  /* clear existing titles/footnotes if requested */
/*  %if %upcase(&clear_tf)=Y %then %do;*/
/*    title; footnote;*/
/*  %end;*/

  /* header */
  title1 j=l "^S={fontstyle=italic}Protocol: &protocol"
         j=r "^S={fontstyle=italic}Page ^{thispage} of ^{lastpage}";
  title2 j=l "^S={fontstyle=italic}Population: &population";

  /* footnote */
  footnote1 "&footnote_text";

  %if %length(&_pgm_path) %then %do;
    footnote4 j=l "^S={fontstyle=italic}&_pgm_path"
              j=r "^S={fontstyle=italic}&run_dt";
  %end;
  %else %do;
    footnote4 j=r "^S={fontstyle=italic}&run_dt";
  %end;

%mend rtf_output_style_setup;

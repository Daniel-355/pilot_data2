/**********************************************************************
 Program:    incidence_rate_plot.sas
 Purpose:    create a incidence rate plot
 Author:     Daniel
 Date:       2026-01-25
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
Read input data
=========================================================*/
 
data adtte01;
   set adam.adtte;  /*time to event*/
/*   paramn=1;*/
run;
 
proc sort data=adtte01;
   by paramn trtan;
run;
 
 
/*=========================================================
Get Kaplan-Meier Estimate of Cumulative Incidence
=========================================================*/
 
/*----------------------------------------------------------
alphaqt option is used to specify the level of significance</br>
notice the usage of method= and conftype= options </br>
notice the usage of plots= options </br>
notice the request for failure plot along with atrisk numbers </br>
number of rows output into the dataset of ProductLimitEstimates is restricted by using timelist= option</br>
----------------------------------------------------------*/
proc lifetest data=adtte01    /*````````````proc lifetest*/
   alphaqt=0.05
   method=km
   plots=survival(failure atrisk=0 to 200 by 25 )
   timelist=(0 to 200 by 25)
   conftype=linear ;
 
   time aval*cnsr(1);
   strata trtan;
   ods output FailurePlot  = sur_fail          ProductLimitEstimates=estimates;
run;
 
/*=========================================================
Select the Number of subjects at risk
=========================================================*/
 
data est(rename=(timelist=time stratum=stratumnum));
   set estimates(keep=stratum timelist left );
run;
 
/*=========================================================
``````````````Output blockplot timepoints and atrisk numebrs
=========================================================*/
 
proc sort data=sur_fail;
   by stratumnum time;
run;
 
data new_survival (drop=j);
   merge est sur_fail ;
   length param_t $100;
   by stratumnum time;

      do j = 0 to 200 by 25;
          if time = j  then do;
            blkrsk = put(left,3.);
            blkx   = time;
         end;
      end;

    trtan = stratumnum;
    param_t="parameter name";
    paramn=1;
run;
 
proc sort data=new_survival;
   by trtan time;
run;
 
/*=========================================================
Build the proc template for the graph
=========================================================*/
 
/*----------------------------------------------------------
Notice the usage of dynamic statement</br>
Notice the usage of entrytitle statment </br>
Notice the usage of attribute mapping </br>
Line attributes: color and pattern </br>
Marker attribures: color and symbol </br>
3 sections: km plot, at risk section label, at risk numbers </br>
Axis attributes: line, ticks, tickvalues, label </br>
Axis type </br>
Axis type attributes </br>
Two plot types in kmplot section: step plot and scatter plot</br>
At risk numbers printed using blockplot</br>
----------------------------------------------------------*/
 
proc template;     /*```````````````set template */
   define statgraph kmplot;
   dynamic x_var y_var1 y_var2 ;
    begingraph;
         *Graph title;
          entrytitle "Category = Time to Event"  /
          textattrs=(size=9pt ) pad=(bottom=20px);
 
         *Colour map;
         discreteattrmap name='colors' / ignorecase=true;
            value 'Placebo'  / lineattrs=(color=blue pattern=shortdash) markerattrs=(color=blue symbol=trianglefilled);
            value 'Low Dose'     / lineattrs=(color=red  pattern=shortdash) markerattrs=(color=red symbol=circlefilled);
            value 'High Dose'     / lineattrs=(color=green  pattern=shortdash) markerattrs=(color=green symbol=squarefilled);
         enddiscreteattrmap;
 
         discreteattrvar attrvar=gmarker var=trtan attrmap='colors';
 
         %*Define 2 block layout and size*;
         layout lattice /rows=3 columns=1 rowweights=(.83 .03 .14) columndatarange=unionall;
 
            %*Start KM plot*;
            layout overlay /
               xaxisopts=(Label="Time at Risk (days)"
               display=(tickvalues line label ticks )
               type=linear
               linearopts=(tickvaluesequence=(start=0 end=200 increment=25)
                    viewmin=0 viewmax=200))
               yaxisopts=( Label="Cumulative Incidence of Subjects with Event"
               type=linear  linearopts= (viewmin=0 viewmax=1) );
 
               StepPlot X=x_var Y=y_var1 / primary=true Group=gmarker
                  LegendLabel="Cumulative Incidence of Subjects with Event" NAME="STEP";
 
               %*Censored observations are suppressed but can be added here*;
               scatterPlot X=x_var Y=y_var2 / Group=gmarker markerattrs=(symbol=plus)
                    LegendLabel="Censored" NAME="SCATTER";
 
               Mergedlegend "STEP" "SCATTER"/
                  location=inside halign=left valign=top across=1 valueattrs=(family="Arial" size=8pt);
            endlayout;
 
            %*** Define left-aligned title for block ***;
            layout overlay;
               entry halign=left 'Number of Subjects at Risk';
            endlayout;
 
            %*Start at risk value plot;
            layout overlay /
               xaxisopts=(type=linear display=none) walldisplay=none;
               blockplot x=blkx block=blkrsk / class=trtan
                  display=(values label)
                  valuehalign=start
                  repeatedvalues=true
                  labelattrs=(family="Arial" size=8pt)
                  valueattrs=(family="Arial" size=8pt);
            endlayout;
         endlayout;
      endgraph;
   end;
run;
 
 
/*=========================================================
Set options for graphs
=========================================================*/
 
  ods listing image_dpi=300;
  ods graphics on / border=off height=13cm width=14.72cm;

%rtf_output_style_setup(
  protocol=XXX01,
  population=%str(Safety Analysis Set),
  pgm_path=%str(C:\XXX01\PROGRAMS\DRAFT\TFLs\ZZZ.sas)
); 
 
title3 "^S={foreground=blue fontweight=bold fontstyle=italic}Cumulative Incidence Plot";
title4 "^S={foreground=blue fontweight=bold fontstyle=italic}Safety Analysis Set";
 
ods rtf file="&outputpath.\incidence_rate_plot.rtf" style=csgpool01;
 
 
/*=========================================================
Create format for treatment presentation
=========================================================*/
/*----------------------------------------------------------
Notice that stratum numbers are used in format creation
----------------------------------------------------------*/
proc format;
   value trtanf
   1="Placebo"
   2="Low Dose"
   3="High Dose"
   ;
run;
 
 
/*=========================================================
```````````````````Generate the graph using sgrender procedure
=========================================================*/
 
proc sgrender data=new_survival template=kmplot;
   dynamic x_var="time" y_var1="_1_survival_" y_var2="_1_censored_" ;
   format trtan trtanf.;                 /*use format here*/
run;
ods graphics off;
ods rtf close;
/*%convert_rtf_to_pdf_vbscript;*/

***********************************************************************
* This is a for HW1 Q6 calculating sample size when comparing two normal means.              *
***********************************************************************;

proc power;
twosamplemeans  /*two independ samples*/
dist=normal /*normal*/
groupweights=(1 1)  /*equal samples*/
alpha=0.05 power=0.80 
stddev=1 /*std deviation*/
   meandiff=2 test=diff /*what is diff , and set as diff test*/
sides=2 /*two sides*/
ntotal=.; /*total nubmer*/
plot min=0.1 max=0.9; 
title "Sample Size Calculation for Comparing Two Normal Means (1:1 Allocation)"; 
run;


/*dichotompus endpoints*/
PROC POWER; TWOSAMPLEFREQ TEST = pchi  
GROUPPROPORTIONS = (0.5 0.4)  ALPHA = 0.05 SIDES = 2 POWER = 0.80 NPERGROUP = .; RUN; 


/*survival times*/
PROC POWER; TWOSAMPLESURVIVAL TEST = logrank GROUPSURVEXPHAZARDS = 0.178 | 0.102 
FOLLOWUPTIME = 6 ACCRUALTIME = 2 POWER = 0.80 ALPHA = 0.05 SIDES = 2 NPERGROUP = .; RUN; 

/*chrome-extension://efaidnbmnnnibpcajpcglclefindmkaj/https://www.lexjansen.com/phuse/2023/as/PAP_AS02.pdf*/



/*libname source "C:\Users\hed2\Downloads\sas practice\SAS-Clinical-Trials-Toolkit-master2\SAS-Clinical-Trials-Toolkit-master";*/
/*libname library "C:\Users\hed2\Downloads\sas practice\SAS-Clinical-Trials-Toolkit-master2\SAS-Clinical-Trials-Toolkit-master";*/
/*libname target "C:\Users\hed2\Downloads\sas practice\SAS-Clinical-Trials-Toolkit-master2\SAS-Clinical-Trials-Toolkit-master\target";*/

options ls=256 nocenter
        EXTENDOBSCOUNTER=NO
        mautosource 
        SASAUTOS = ("!SASROOT\core\sasmacro",      "!SASROOT\aacomp\sasmacro",
                    "!SASROOT\accelmva\sasmacro",  "!SASROOT\cstframework\sasmacro",          
                    "!SASROOT\dmscore\sasmacro",   "!SASROOT\genetics\sasmacro",          
                    "!SASROOT\graph\sasmacro",     "!SASROOT\hps\sasmacro",          
                    "!SASROOT\iml\sasmacro",       "!SASROOT\inttech\sasmacro",   
                    "!SASROOT\stat\sasmacro",      
                    "C:\Users\hed2\Downloads\sas practice\SAS-Clinical-Trials-Toolkit-master2\SAS-Clinical-Trials-Toolkit-master");

/*%include 'C:\Users\hed2\Downloads\sas practice\SAS-Clinical-Trials-Toolkit-master2\SAS-Clinical-Trials-Toolkit-master/make_sdtm_dy2.sas';*/
/*%include 'C:\Users\hed2\Downloads\sas practice\SAS-Clinical-Trials-Toolkit-master2\SAS-Clinical-Trials-Toolkit-master/make_sort_order.sas';*/
/*%include 'C:\Users\hed2\Downloads\sas practice\SAS-Clinical-Trials-Toolkit-master2\SAS-Clinical-Trials-Toolkit-master/make_empty_dataset.sas';*/



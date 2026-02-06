/*************convert sas into xpt************/
/* path to store xpt file*/
%let path_out= C:\Users\hed2\Downloads\sas practice\SAS-Clinical-Trials-Toolkit-master2\SAS-Clinical-Trials-Toolkit-master\xpt;
/* path to address sas dataset*/
%let path_in= C:\Users\hed2\Downloads\sas practice\SAS-Clinical-Trials-Toolkit-master2\SAS-Clinical-Trials-Toolkit-master\target;


/*transform a sas file into a xpt dataset*/
libname in v9 "&path_in";
data _null_;
rc=filename('x',"&path_in");
did=dopen('x');
do i=1 to dnum(did);
  memname=dread(did,i);
call execute(cat("libname tranfile xport '&path_out\",scan(memname,1,'.'),".xpt';proc copy in=in out=tranfile;select ",scan(memname,1,'.'),";run;"));
end;

run;

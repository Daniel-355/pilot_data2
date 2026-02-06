/*run all*/
/*run all sas under this folder*/
/*daniel*/
/*2026-01-07*/


%macro run_all_sas(dir=);

  filename sasdir "&dir";

  data _null_;
    did = dopen('sasdir');
    if did > 0 then do i = 1 to dnum(did);
      fname = dread(did, i);
      if lowcase(scan(fname, -1, '.')) = 'sas' then do;
        call execute(cats('%nrstr(%include "', "&dir/", fname, '";)'));
      end;
    end;
    rc = dclose(did);
  run;

%mend;

/* run */
%run_all_sas(dir=C:\Users\hed2\Downloads\Clinical_Trial_2025_DrugA_Phase3\08_Reports\Regulatory_Submission\Submission data files\Programs\production\sdtm);

/****************************************
This program is for HW1Q5 practicing randomization.
***************************************/
Options nodate;

/*two centers*/

*For Center1 n=24 block size=6;
data values1;
samplesize=24;
blocksize=6;
run;

data random1;
set values1;
nblocks=round(samplesize/blocksize);  /*how many blocks 4*/
na=round(blocksize/2);  /*how many samples in group a in each block 3*/
nb=blocksize-na;   /*how many in group b 3 */

do block=1 to nblocks by 1; /*4*/
   nna=0;
   nnb=0; /*return zero */

   do i=1 to blocksize; /*6*/
      subject=i+((block-1)*blocksize); /*1+ (0)*6 */ /*1-6,7-12...*/ 

/*      if nna=na then treatment="B"; /*3*/*/
/*      if nnb=nb then treatment="A"; /*3*/*/

           else do;
         aprob=(na-nna)/(na+nb-nna-nnb); /*3-0 / 6-0-0*/ /*enter group a probability*/

         u=ranuni(0); /*uniform random nuber*/

         if (0<=u<=aprob) then do;
            treatment="A";
            nna=nna+1;
         end;
         if (aprob<u<=1) then do;
            treatment="B";
            nnb=nnb+1;
         end;
      end;
/*      keep subject treatment;*/
      output;
   end;
end;
run;
proc print data=random1;
/*id subject;*/
/*var treatment;*/
title "Randomization Plan for Treatments A and B -Center1";
run;

*For Center2 n=36 block size=6;
data values2;
samplesize=36;
blocksize=6;
run;
data random2;
set values2;
nblocks=round(samplesize/blocksize);
na=round(blocksize/2);
nb=blocksize-na;
do block=1 to nblocks by 1;
   nna=0;
   nnb=0;
   do i=1 to blocksize;
      subject=i+((block-1)*blocksize);
      if nna=na then treatment="B";
      if nnb=nb then treatment="A";
      else do;
         aprob=(na-nna)/(na+nb-nna-nnb);
         u=ranuni(0);
         if (0<=u<=aprob) then do;
            treatment="A";
            nna=nna+1;
         end;
         if (aprob<u<=1) then do;
            treatment="B";
            nnb=nnb+1;
         end;
      end;
/*      keep subject treatment;*/
      output;
   end;
end;
run;
proc print data=random2 split='/';
/*id subject;*/
/*var treatment;*/
title "Randomization Plan for Treatments A and B Center2";
run;

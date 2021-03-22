/* # Update/change the MYSTRGACC= value with your storage account from your environment */

%let MYSTRGACC="YOUR_USERNAMEadls2";

%let MYSTRGFS="fsdata";
%let MYTNTID="b1c14d5c-3625-45b3-a430-9552373a0c2f";
%let MYAPPID="a2e7cfdc-93f8-4f12-9eda-81cf09a84566";

options azuretenantid= &MYTNTID;

filename out adls "sasfile/filename/filename.txt"
applicationid=&MYAPPID
accountname=&MYSTRGACC
filesystem=&MYSTRGFS
;

data _null_;
   file out;
   put 'line 1';
   put 'line 2';
run;

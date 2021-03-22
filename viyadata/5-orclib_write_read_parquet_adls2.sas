/* # Update/change the MYSTRGACC= value with your storage account from your environment */

%let MYSTRGACC="YOUR_USERNAMEadls2";

%let MYSTRGFS="fsdata";
%let MYTNTID="b1c14d5c-3625-45b3-a430-9552373a0c2f";
%let MYAPPID="a2e7cfdc-93f8-4f12-9eda-81cf09a84566";

CAS mySession  SESSOPTS=(CASLIB=casuser TIMEOUT=99 LOCALE="en_US" metrics=true);

caslib ADLS2 datasource=(
      srctype="adls",
      accountname=&MYSTRGACC,
      filesystem=&MYSTRGFS,
      dnsSuffix=dfs.core.windows.net,
      timeout=50000,
      tenantid=&MYTNTID ,
      applicationId=&MYAPPID
   )
   path="/sample_data/parquet"
   subdirs;

proc casutil incaslib="ADLS2";
   list files ;
run;

/* Save CAS Data to ADLS2 storage data file (parquet) */
proc casutil incaslib="ADLS2" outcaslib="ADLS2" ;
load data=sashelp.cars casout="cars" replace;
save casdata="cars" casout="cars.parquet"  replace;
list files;
quit;


/* CAS load from ADLS2 storage data file */
proc casutil  incaslib="ADLS2"  outcaslib="ADLS2";
  load casdata="cars.parquet" casout="cars_parquet" replace ;
  list tables ;
run;
quit;

cas mysession terminate;

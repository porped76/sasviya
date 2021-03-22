/* # Update/change the MYSTRGACC= value with your storage account from your environment */

%let MYSTRGACC="YOUR_USERNAMEadls2";

%let MYSTRGFS="fsdata";
%let MYTNTID="b1c14d5c-3625-45b3-a430-9552373a0c2f";
%let MYAPPID="a2e7cfdc-93f8-4f12-9eda-81cf09a84566";

libname orclibN ORC "/sample_data/orc_n_files"
      storage_account_name = &MYSTRGACC
      storage_file_system = &MYSTRGFS
      storage_dns_suffix = "dfs.core.windows.net"
      storage_application_id=&MYAPPID
      storage_tenant_id=&MYTNTID
      DIRECTORIES_AS_DATA=YES
      FILE_NAME_EXTENSION=(orc ORC)
;

data orclibN.fish_0;
   set sashelp.fish;
run;

data orclibN.fish_1;
   set sashelp.fish;
run;

data orclibN.fish_2;
   set sashelp.fish;
run;

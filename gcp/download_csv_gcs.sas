/* Store token */
%let GCSTOKEN=ya29.a0ARrdaM-UEW1RjNTK5vKDw-XWcDLm8m3UVPIk4gk3EA-0YkH9YU3WdmL8nM5vPLRn5KqoqBbAQYuRLgvPVEnhZo1BH-dJ5-_RGoTz9HWyILKWD6t_WQ27smi4gkS4yq-S7hExJ6RkPI8tJ6J3DrwYAG97pCYJ;

/* Fileref */
filename outcsv "$HOME/cars.csv";

/* Download the file using the REST API */
proc http
    url="https://storage.googleapis.com/storage/v1/b/ibe-bucket/o/cars.csv?alt=media"
    oauth_bearer="&GCSTOKEN"
    out=outcsv ;
    debug level=1 ;
run ;

proc import datafile="$HOME/cars.csv"
        out=cars
        dbms=csv
        replace;
	getnames=no;
run;

proc print data=work.cars;
run;

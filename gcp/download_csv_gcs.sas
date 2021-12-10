/* Store token */
%let GCSTOKEN=;

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

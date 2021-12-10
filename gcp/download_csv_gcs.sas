/* Store token */
%let GCSTOKEN=ya29.a0ARrdaM8lhH8yteRhw-7HWbifvX5gAFPl3InXaQNjMvdkc3_n6vcwOxCTgmGNbNT6mxbmhLVQmTm5FLlMXZVGXjxtN_PCdni6Ur-PN_Wn3dO8hXk2oSuGI9WKP0LTokJVLBf99UJPBwdqnbcdNRpOtdDH5sZr;

/* Fileref */
filename outcsv "$HOME/source-data/cars.csv";

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

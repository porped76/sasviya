/* Store token */
%let GCSTOKEN=ya29.a0ARrdaM8lhH8yteRhw-7HWbifvX5gAFPl3InXaQNjMvdkc3_n6vcwOxCTgmGNbNT6mxbmhLVQmTm5FLlMXZVGXjxtN_PCdni6Ur-PN_Wn3dO8hXk2oSuGI9WKP0LTokJVLBf99UJPBwdqnbcdNRpOtdDH5sZr;

/* Fileref */
filename incsv "$HOME/source-data/cars.csv";

/* Upload the file using the REST API */
proc http
    url="https://storage.googleapis.com/upload/storage/v1/b/ibe-bucket/o?uploadType=media%nrstr(&)name=cars_upload.csv"
    oauth_bearer="&GCSTOKEN"
    in=incsv ;
	headers "Content-type"="text/csv" ;
    debug level=1 ;
run ;

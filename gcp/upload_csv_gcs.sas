/* Store token */
%let GCSTOKEN=;

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

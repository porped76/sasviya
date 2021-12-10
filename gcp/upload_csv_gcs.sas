/* Store token */
%let GCSTOKEN=ya29.a0ARrdaM-UEW1RjNTK5vKDw-XWcDLm8m3UVPIk4gk3EA-0YkH9YU3WdmL8nM5vPLRn5KqoqBbAQYuRLgvPVEnhZo1BH-dJ5-_RGoTz9HWyILKWD6t_WQ27smi4gkS4yq-S7hExJ6RkPI8tJ6J3DrwYAG97pCYJ;

/* Fileref */
filename incsv "$HOME/cars.csv";

/* Upload the file using the REST API */
proc http
    url="https://storage.googleapis.com/upload/storage/v1/b/ibe-bucket/o?uploadType=media%nrstr(&)name=cars_upload.csv"
    oauth_bearer="&GCSTOKEN"
    in=incsv ;
	headers "Content-type"="text/csv" ;
    debug level=1 ;
run ;

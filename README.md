# SyncAndDumpS3

The purpose of this script is to:
1) Sync two existing s3 buckets
2) Create a mysql and Mongodb dump file, compress it as .gz and then upload the files to s3 bucket specified as UPLOAD_BUCKET.
3) The uploaded dumps are categorised in two formats, one as a latest.gz file and the other as Timestamp.gz file for ease of access while restoring any dump. We can differentiate between the latest and the older dump files.

Please add a star or write to ankushors789@gmail.com if you like the work done!! 

-Cheers
---Ankush

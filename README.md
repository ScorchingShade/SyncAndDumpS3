# SyncAndDumpS3

The purpose of this script is to:
1) Sync two existing s3 buckets
2) Create a mysql and Mongodb dump file, compress it as .gz and then upload the files to s3 bucket specified as UPLOAD_BUCKET.
3) The uploaded dumps are categorised in two formats, one as a latest.gz file and the other as Timestamp.gz file for ease of access while restoring any dump. We can differentiate between the latest and the older dump files.

SyncAndDumpS3 is strictly a very specific use case app. It has a specific function of automating the above mentioned tasks.
Please do not use for any other purpose other than the ones mentioned.

##Features
1) Support for local machines as well as servers.
2) Fully functional syncing of two buckets.
3) Configuration Options for Environment variables.
4) Easy to use menu driven , single session programme.

##How To Install!
Use the following command to install SyncAndDumpS3 on your ubuntu machine-
`sudo snap install sync-and-dump-s3`
<br>
To use the software, use the command-
`sync-and-dump-s3`

###Add Ons
Additional features include support to connect to a db on a server...uncomment the line number 154 and 225 and comment the lines 227 and 156 to include support for contacting a db on external server.
#####Command for mods
vim /snap/sync-and-dump-s3/1/bin/syncScript.sh



Please add a star or write to ankushors789@gmail.com if you like the work done!! 

-Cheers
---Ankush

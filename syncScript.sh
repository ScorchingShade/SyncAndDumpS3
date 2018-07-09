#!/bin/bash
##################
#The purpose of the script is to--
# a) To sync two buckets with public read permission
# b) To take data dump from mongodb and Mysql and upload it as a Gzip on an s3 bucket.
##################


##Variables to define USERNAME , Hostname and Paswsword for mysql#################
#HOSTNAME=""
#USER=""
#PASS=""
##################################################################################


##Variables to define USERNAME , Hostname and Paswsword for mongodb###############
#HOSTNAMEMong=""
#USERMong=""
#PASSMong=""
#PORT=""
##################################################################################

###CUSTOM VARIABLES###
LATEST_TAG="/tmp/Gzip/latestmysql"
SOURCE_BUCKET="s3://ankush-dump-3"
DESTINATION_BUCKET="s3://ankush-dump-2"
ACL_POLICY="public-read"
SCRIPT_STATE="run" #specify script state to either run or stop stop the script
UPLOAD_BUCKET="s3://ankush-dump-3"
MDPath="MongoDumps"
MD_DB_NAME="ankushKaDb"

DATABASE_NAME="Ankush_Intern_mysql"
DB_DUMP_PATH="/tmp/Gzip/dump.sql"
GZIP_DIR="/tmp/Gzip/"

GZIP_DIR1="/tmp/Gzip1/"




####Custom Commands, called on demand########
TMP=`mkdir -p /tmp/Gzip && cd /tmp/Gzip`
FIND_TMP=`find /tmp/Gzip/ |xargs|awk '{print $1}'`

TMP1=`mkdir -p /tmp/Gzip1 && cd /tmp/Gzip1`
FIND_TMP1=`find /tmp/Gzip1/ |xargs|awk '{print $1}'`



#########################progresss bar############################################
progress_bar()
{
  local DURATION=$1
  local INT=0.25      # refresh interval

  local TIME=0
  local CURLEN=0
  local SECS=0
  local FRACTION=0

  local FB=2588       # full block

  trap "echo -e $(tput cnorm); trap - SIGINT; return" SIGINT

  echo -ne "$(tput civis)\r$(tput el)│"                # clean line

  local START=$( date +%s%N )

  while [ $SECS -lt $DURATION ]; do
    local COLS=$( tput cols )

    # main bar
    local L=$( bc -l <<< "( ( $COLS - 5 ) * $TIME  ) / ($DURATION-$INT)" | awk '{ printf "%f", $0 }' )
    local N=$( bc -l <<< $L                                              | awk '{ printf "%d", $0 }' )

    [ $FRACTION -ne 0 ] && echo -ne "$( tput cub 1 )"  # erase partial block

    if [ $N -gt $CURLEN ]; then
      for i in $( seq 1 $(( N - CURLEN )) ); do
        echo -ne \\u$FB
      done
      CURLEN=$N
    fi

    # partial block adjustment
    FRACTION=$( bc -l <<< "( $L - $N ) * 8" | awk '{ printf "%.0f", $0 }' )

    if [ $FRACTION -ne 0 ]; then 
      local PB=$( printf %x $(( 0x258F - FRACTION + 1 )) )
      echo -ne \\u$PB
    fi

    # percentage progress
    local PROGRESS=$( bc -l <<< "( 100 * $TIME ) / ($DURATION-$INT)" | awk '{ printf "%.0f", $0 }' )
    echo -ne "$( tput sc )"                            # save pos
    echo -ne "\r$( tput cuf $(( COLS - 6 )) )"         # move cur
    echo -ne "│ $PROGRESS%"
    echo -ne "$( tput rc )"                            # restore pos

    TIME=$( bc -l <<< "$TIME + $INT" | awk '{ printf "%f", $0 }' )
    SECS=$( bc -l <<<  $TIME         | awk '{ printf "%d", $0 }' )

    # take into account loop execution time
    local END=$( date +%s%N )
    local DELTA=$( bc -l <<< "$INT - ( $END - $START )/1000000000" \
                   | awk '{ if ( $0 > 0 ) printf "%f", $0; else print "0" }' )
    sleep $DELTA
    START=$( date +%s%N )
  done

  echo $(tput cnorm)
  trap - SIGINT
}


################################################################################################################


######syncing buckets in s3 with specified policcy
function syncBuckets(){
	printf "Syncing $SOURCE_BUCKET and $DESTINATION_BUCKET  now, please wait.......\n"
	aws s3 sync --acl $ACL_POLICY  $SOURCE_BUCKET $DESTINATION_BUCKET
	progress_bar 3	
	printf "sync Successfully done\n"
}



########Mysql dump upload to s3
function mysqlDumper(){
	if [ $FIND_TMP != $PWD ];
	then 
		printf "Switching Directories temporarily to do some work here.....................\n"
		echo $TMP
		
		####################mysql dump with hostname and username and password for different server backup------------
		#sudo mysqldump -h $HOSTNAME -u $USER -p$PASS -B $DATABASE_NAME >$DB_DUMP_PATH
		##############################################################################################################
		
		printf "Creating dump from your mysqldb..........................\n"
		progress_bar 1
		sudo mysqldump $DATABASE_NAME >$DB_DUMP_PATH
		gzip $DB_DUMP_PATH
		printf "Successfully created .gz file for mysql dump for database $DATABASE_NAME.......................\n" 
		
		cp $DB_DUMP_PATH.gz $LATEST_TAG.gz
		cp $DB_DUMP_PATH.gz $GZIP_DIR$(date -d "today" +"%Y_%m_%d_%H_%M_%S")mysql.gz
		
		TIMESTAMPTAG="$(ls /tmp/Gzip/|xargs|awk '{print $1}')"
		
		printf "Beginning Upload for latest.gz and timestamp.gz on bucket $UPLOAD_BUCKET............\n"
		
		echo `aws s3 cp $LATEST_TAG.gz $UPLOAD_BUCKET`
		progress_bar 4
		echo `aws s3 cp $GZIP_DIR$TIMESTAMPTAG $UPLOAD_BUCKET`
		progress_bar 4
		printf "Finished tasks, bucket at $UPLOAD_BUCKET has following files\n"
		progress_bar 2
		aws s3 ls $UPLOAD_BUCKET

		printf "Removing Temporary Folder and files......................\n"
		rm -r /tmp/Gzip/
		printf "##############################################Successfull##############################################\n\n\n"

fi
	

}

##########mongoDb upload to s3
function mongodbDumper(){
	if [ $FIND_TMP1 != $PWD ];
	then 
		printf "Switching Directories temporarily to do some work here.....................\n"
		echo $TMP1
		
		#####################mongoDump dump with hostname and username and port and password for different server backup------------------------
		#sudo mongodump --host $HOSTNAMEMong --port $PORT --username $USERMong --password $PASSMong --out $MDPath --db $MD_DB_NAME
		#########################################################################################################################################
		printf "Creating dump from your mysqldb..........................\n"
		progress_bar 1
		sudo mongodump -o $MDPath --db $MD_DB_NAME 
		tar -zcf $MD_DB_NAME.tar.gz $MDPath
		
		cp $MD_DB_NAME.tar.gz /tmp/Gzip1/Latestmongo.tar.gz
		cp $MD_DB_NAME.tar.gz $GZIP_DIR1$(date -d "today" +"%Y_%m_%d_%H_%M_%S")mongo.tar.gz
		
		TIMESTAMPTAG="$(ls /tmp/Gzip1/|xargs|awk '{print $1}')"
		
		printf "Beginning Upload for latest.gz and timestamp.gz on bucket $UPLOAD_BUCKET............\n"
		echo `aws s3 cp /tmp/Gzip1/Latestmongo.tar.gz $UPLOAD_BUCKET`
		progress_bar 4
		echo `aws s3 cp $GZIP_DIR1$TIMESTAMPTAG $UPLOAD_BUCKET`
		progress_bar 4
		printf "Finished tasks, bucket at $UPLOAD_BUCKET has following files\n"
		aws s3 ls $UPLOAD_BUCKET
		progress_bar 2

		printf "Removing Temporary Folder and files......................\n"
		rm -r /tmp/Gzip1/
		printf "##############################################Successfull##############################################\n"

fi
}

case $SCRIPT_STATE in 
	"run")
		syncBuckets	
		mysqlDumper
		mongodbDumper
	;;
	 *)
  	;;
esac
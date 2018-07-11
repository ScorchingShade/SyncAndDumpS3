#!/bin/bash
##################
#The purpose of the script is to--
# a) To sync two buckets with public read permission
# b) To take data dump from mongodb and Mysql and upload it as a Gzip on an s3 bucket.
##################


##Variables to define USERNAME , Hostname and Paswsword for mysql#################
HOSTNAME_SQL=""
USER_SQL=""
PASS_SQL=""
##################################################################################


##Variables to define USERNAME , Hostname and Paswsword for mongodb###############
HOSTNAMEMong=""
USERMong=""
PASSMong=""
PORT=""
##################################################################################

###CUSTOM VARIABLES###
SCRIPT_STATE=$1 #specify script state to either run or stop stop the script
SQL_PATH="mysqldump"
MONGO_PATH="mongodump"
AWS_PATH="aws"
########s3 vars
SOURCE_BUCKET="s3://ankush-dump-3"
DESTINATION_BUCKET="s3://ankush-dump-2"
ACL_POLICY="public-read"
UPLOAD_BUCKET="s3://ankush-dump-3"

LATEST_TAG="/tmp/Gzip/latestmysql"
LATEST_TAG_MONGO="/tmp/Gzip1/Latestmongo"

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
	$AWS_PATH s3 sync --acl $ACL_POLICY  $SOURCE_BUCKET $DESTINATION_BUCKET
	if [ $? -eq 0 ];then
		progress_bar 3	
		printf "sync Successfully done\n"
	else
 		echo "Error in syncing...program will terminate"
 		exit 1
	fi
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
		sudo $SQL_PATH $DATABASE_NAME >$DB_DUMP_PATH
		if [ $? -eq 0 ];then
			progress_bar 1	
			printf "Dump created Successfully\n"
		else
 			echo "Error in Creating dump...program will terminate"
 			exit 1
		fi

		gzip $DB_DUMP_PATH
		if [ $? -eq 0 ];then
			printf "Successfully created .gz file for mysql dump for database $DATABASE_NAME.......................\n" 
		else
 			echo "Error in creating gzip file...program will terminate"
 			exit 1
		fi
		
		
		cp $DB_DUMP_PATH.gz $LATEST_TAG.gz
		cp $DB_DUMP_PATH.gz $GZIP_DIR$(date -d "today" +"%Y_%m_%d_%H_%M_%S")mysql.gz
		
		TIMESTAMPTAG="$(ls /tmp/Gzip/|xargs|awk '{print $1}')"
		
		printf "Beginning Upload for latest.gz and timestamp.gz on bucket $UPLOAD_BUCKET............\n"
		
		echo `aws s3 cp $LATEST_TAG.gz $UPLOAD_BUCKET`
		if [ $? -eq 0 ];then
			progress_bar 4	
		else
 			echo "Error in Upload...program will terminate"
 			exit 1
		fi

		echo `aws s3 cp $GZIP_DIR$TIMESTAMPTAG $UPLOAD_BUCKET`
		if [ $? -eq 0 ];then
			progress_bar 4	
		else
 			echo "Error in Upload...program will terminate"
 			exit 1
		fi
		
		printf "Finished tasks, bucket at $UPLOAD_BUCKET has following files\n"
		aws s3 ls $UPLOAD_BUCKET
		if [ $? -eq 0 ];then
			progress_bar 2
		else
 			echo "Error in contacting aws...program will terminate"
 			exit 1
		fi

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
		printf "Creating dump from your mongodb..........................\n"
		progress_bar 1
		sudo $MONGO_PATH -o $MDPath --db $MD_DB_NAME 
		if [ $? -eq 0 ];then
			progress_bar 1	
			printf "Dump created Successfully\n"
		else
 			echo "Error in Creating dump...program will terminate"
 			exit 1
		fi

		tar -zcf $MD_DB_NAME.tar.gz $MDPath
		if [ $? -eq 0 ];then
			progress_bar 1	
			printf "Zipped Successfully.....\n"
		else
 			echo "Error in Creating tar.gz...program will terminate"
 			exit 1
		fi

		cp $MD_DB_NAME.tar.gz $LATEST_TAG_MONGO.tar.gz
		cp $MD_DB_NAME.tar.gz $GZIP_DIR1$(date -d "today" +"%Y_%m_%d_%H_%M_%S")mongo.tar.gz
		
		TIMESTAMPTAG="$(ls /tmp/Gzip1/|xargs|awk '{print $1}')"
		
		printf "Beginning Upload for latest.gz and timestamp.gz on bucket $UPLOAD_BUCKET............\n"
		echo `aws s3 cp /tmp/Gzip1/Latestmongo.tar.gz $UPLOAD_BUCKET`
		if [ $? -eq 0 ];then
			progress_bar 4	
		else
 			echo "Error in Upload...program will terminate"
 			exit 1
		fi
		echo `aws s3 cp $GZIP_DIR1$TIMESTAMPTAG $UPLOAD_BUCKET`
		if [ $? -eq 0 ];then
			progress_bar 4	
		else
 			echo "Error in Upload...program will terminate"
 			exit 1
		fi

		printf "Finished tasks, bucket at $UPLOAD_BUCKET has following files\n"
		aws s3 ls $UPLOAD_BUCKET
		if [ $? -eq 0 ];then
			progress_bar 2	
		else
 			echo "Error in Conctacting aws...program will terminate"
 			exit 1
		fi

		printf "Removing Temporary Folder and files......................\n"
		rm -r /tmp/Gzip1/
		printf "##############################################Successfull##############################################\n"

fi
}

case $SCRIPT_STATE in 
	"sync")
		syncBuckets	
	;;
	
	"dumpmysql")
		mysqlDumper
	;;
	 
	"dumpmongo")
		mongodbDumper
	;;
	*)
	;;
	 
esac


function myvars(){
	
	printf "Do you wish to configure default settings for SyncAndDump S3? (press y for yes and n for no): "
	read Defresponse
	if [ "$Defresponse" = "y" ] || [ "$Defresponse" = "yes" ] || [ "$Defresponse" = "Y" ] || [ "$Defresponse" = "Yes" ] || [ "$Defresponse" = "YES" ];then
		printf "Enter the value for Mysql Hostname ($HOSTNAME_SQL):"
		read host
		
		if [ "$host" != NULL ]; then
		  		HOSTNAME_SQL= $host
		else
			continue
		  	fi  	


		printf "Enter the value for Mysql Username ($USER_SQL):"
		read user
		
		if [ "$user" != NULL ]; then
		  		USER_SQL= $user
		  	fi  	
  		
  		printf "Enter the value for Mysql password ($PASS_SQL):"
		read pass
		
		if [ "$pass" != NULL ]; then
		  		PASS_SQL= $pass
		  	fi  	

		printf "Enter the value for Mongodb Hostname ($HOSTNAMEMong):"  	
		read hostm
		if [ "$hostm" != NULL ]; then
		  		HOSTNAMEMong= $hostm
		else
			continue
		  	fi  	


		printf "Enter the value for Mongodb Username ($USERMong):"
		read userm
		
		if [ "$userm" != NULL ]; then
		  		USERMong= $userm
		  	fi  	
  		
  		printf "Enter the value for Mongodb password ($PASSMong):"
		read passm
		
		if [ "$passm" != NULL ]; then
		  		PASSMong= $passm
		  	fi  	
	
	printf "Enter the value for aws path ($AWS_PATH):"
		read patha
		
		if [ "$patha" != NULL ]; then
		  		AWS_PATH= $patha
		  	fi  	

	printf "Enter the value for Source bucket ($SOURCE_BUCKET):"
		read sourceb
		
		if [ "$sourceb" != NULL ]; then
		  		SOURCE_BUCKET= $sourceb
		  	fi  	

	printf "Enter the value for Destination Bucket ($DESTINATION_BUCKET):"
		read destb
		
		if [ "$destb" != NULL ]; then
		  		DESTINATION_BUCKET= $destb
		  	fi  	


	printf "Enter the value for ACL Policy ($ACL_POLICY):"
		read policy
		
		if [ "$policy" != NULL ]; then
		  		ACL_POLICY= $policy
		  	fi  	

	printf "Enter the value for Dump upload bucket ($UPLOAD_BUCKET):"
		read upBucket
		
		if [ "$upBucket" != NULL ]; then
		  		UPLOAD_BUCKET= $upBucket
		  	fi 

	printf "Enter the value for latest mysql dump name ($LATEST_TAG):"
		read latesttag
		
		if [ "$latesttag" != NULL ]; then
		  		LATEST_TAG= $latesttag
		  	fi 

	printf "Enter the value for latest mongodb dump name ($LATEST_TAG_MONGO):"
		read latesttagm
		
		if [ "$latesttagm" != NULL ]; then
		  		LATEST_TAG_MONGO= $latesttagm
		  	fi 


	printf "Enter the value for mongodb database name ($MD_DB_NAME):"
		read dbnamem
		
		if [ "$dbnamem" != NULL ]; then
		  		MD_DB_NAME= $dbnamem
		  	fi 


	printf "Enter the value for latest mongodb dump name ($LATEST_TAG_MONGO):"
		read latesttagm
		
		if [ "$latesttagm" != NULL ]; then
		  		LATEST_TAG_MONGO= $latesttagm
		  	fi 


	else
		printf "Enter your choice from below: \n1)Press 1 for Syncing Buckets\n2)Press 2 for mysql dump upload\n3)Press 3 for mongodb dump upload\n"
		read choice
		case $choice in 
	"1")
		syncBuckets	
	;;
	
	"2")
		mysqlDumper
	;;
	 
	"3")
		mongodbDumper
	;;
	*)
	;;
	 
esac
	fi
}

 
	while true
	do
		myvars
		printf "Do you wish to continue?(y/n):\n"
		read choice

		if [ "$choice" = "n" ] || [ "$choice" = "N" ] || [ "$choice" = "no" ] || [ "$choice" = "NO" ] || [ "$choice" = "No" ];then
			printf "Cya later!\n"
			exit
		
		elif [ "$choice" = "y" ] || [ "$choice" = "Y" ] || [ "$choice" = "yes" ] || [ "$choice" = "YES" ] || [ "$choice" = "Yes" ];then
			continue
		
		else 
			printf "Wrong choice , program will now terminate...\n"
			exit
		fi

	done

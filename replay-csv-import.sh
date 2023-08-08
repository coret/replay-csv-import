#!/bin/bash

# check prerequisites

if ! command -v jq >/dev/null 2>&1; then
    echo "FAIL: jq is not installed, please install before running $0"
	exit 1
fi

if ! command -v mysql >/dev/null 2>&1; then
    echo "FAIL: mysql (client) is not installed, please install before running $0"
	exit 1
fi

# check/load configuration

if [ ! -e replay-csv-import.env ]; then
	echo "FAIL: the configuration of $0 should be available in replay-csv-import.env"
	exit 1
fi

source replay-csv-import.env

display_help() {
    echo "Usage: $0 -csv [filename] -job [id]"
    echo
    echo "   -help              Display this help message and exit"
    echo "   -csv [filename]    Specify the filename of the CSV/TSV file"
	echo "   -job [id]          The job ID to replicate"
}

csv_file=""
job_id=""

# parse command-line arguments

while [ "$1" != "" ]; do
    case $1 in
        -help )		display_help
					exit 0
					;;
        -csv )		shift
		            if [[ ! "$1" || "$1" == -* ]]; then
						echo "ERROR: -csv option requires a value." >&2
						exit 1
					fi
					csv_file="$1"
					;;
        -job )		shift
		            if [[ ! "$1" || "$1" == -* ]]; then
						echo "ERROR: -job option requires a value." >&2
						exit 1
					fi
					job_id="$1"
					;;
        * )			echo "ERROR: Unknown parameter $1" >&2
					exit 1
					;;
    esac
    shift # Shift to the next argument
done

# check command-line parameters

if [[ "$csv_file" == "" ]]; then
	echo "ERROR: a value for csv is required" >&2
	exit 1
else 
	if [[ ! -e "$csv_file" ]]; then
		echo "ERROR: can't find the file $csv_file" >&2
		exit 1	
	fi
fi

if [[ "$job_id" == "" ]]; then
	echo "ERROR: a value for job is required" >&2
	exit 1
else
	if [[ ! $job_id =~ ^[0-9]+$ ]]; then
		echo "ERROR: the value for job should be a number" >&2
		exit 1
	fi
fi

# read database configuration

if [ ! -e "$OMEKA_DIRECTORY/config/database.ini" ]; then
	echo "ERROR: can't read $OMEKA_DIRECTORY/config/database.ini - please the value of OMEKA_DIRECTORY"
	exit 1;
fi

while IFS='=' read -r key value
do
    key=$(echo $key | xargs)
    value=$(echo $value | xargs)
    if [[ $key == "" || $key == \#* || $key == \;* ]]; then
        continue
    fi
    value=$(echo $value | tr -d '"')
    export $key="$value"
done < "$OMEKA_DIRECTORY/config/database.ini"

# check if job exists and is a CSVImport\Job\Import, if so copy job record and call perform-job

mysql --host=$host --user=$user --password=$password --skip-column-names -e "SELECT owner_id,class, args FROM job WHERE id=$job_id" $dbname | while read -r owner_id class args; do
	if [[ "$class" == "CSVImport\\\\Job\\\\Import" ]] ; then
		# copy file to tmp file from filepath
		filepath=$(echo "$args" |  jq -r '.filepath | gsub("\\\\\/"; "/")')
		cp "$csv_file" $filepath
		# file $filepath - usually in /tmp/ - is removed automatically after job is performed
		new_job_id=`mysql --host=$host --user=$user --password=$password --skip-column-names -e "INSERT INTO job(owner_id,class,args,started) VALUES ($owner_id,'$class','$args', NOW()); SELECT LAST_INSERT_ID();" $dbname`
		echo "running job, track via $OMEKA_SERVER_URL$OMEKA_BASE_PATH/admin/job/$new_job_id"
		php $OMEKA_DIRECTORY/application/data/scripts/perform-job.php --job-id $new_job_id --base-path $OMEKA_BASE_PATH --server-url $OMEKA_SERVER_URL
	else 
		echo "ERROR: the provided job id is not a CSVImport\Job\Import class: $class" >&2
		exit 1
	fi
done
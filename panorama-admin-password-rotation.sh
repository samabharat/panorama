#!/bin/bash

set -e

function die {
	printf "Error: %s\n" "$*" 1>&2
	exit 1
}


DEVOPS_USR=serviceaccount
DEVOPS_PASS=serviceacctpass

ADMIN_USR='admin'
ADMIN_PASS=currentpass
NEW_ADMIN_PASS=newpass


SERVER=10.x.x.x

function send {
   curl -Ssk -u $DEVOPS_USR:$DEVOPS_PASS -X POST  https://$SERVER/api/ \
	-H 'Accept: application/xml' \
  	-H 'Content-Type: application/x-www-form-urlencoded' \
	-d "$1"
}

function get_api_key {
  	send "type=keygen&user=$ADMIN_USR&password=$ADMIN_PASS"
}

function get_password_hash {
        send "type=op&cmd=<request><password-hash><password>$NEW_ADMIN_PASS</password></password-hash></request>"
}

function updated_password {
        send "type=config&action=set&key=$API_KEY&xpath=/config/mgt-config/users/entry[@name='$ADMIN_USR']&element=<phash>$PASS_HASH</phash>"
}

function commit {
       send "type=commit&cmd=<commit></commit>"
}

function get_job_status {
	send "type=op&cmd=<show><jobs><id>$1</id></jobs></show>"
}

function check_for_errors {
	if [[ $1 =~ "403" ]] || [[ $1 =~ "error" ]]; then 
	case $2 in
		get_api_key)
	  		die "Step 1 - Failed to get the API Key. response is $1"
			;;
		get_password_hash)
	  		die "Step 2 - Failed to generate password hash. response is $1"
			;;
		update_password)
	  		die "Step 3 - Failed to update password. response is $1"
			;;
		commit)
	  		die "Step 4 - Failed to commit new password. response is $1"
			;;
		*)
			echo "Unknow failure. reponse is $1"
			;;
	  esac
	fi 
}

# Get API token of the account that is being renewed
api_response=$(get_api_key)
check_for_errors "$api_response" "get_api_key"
API_KEY=$(xmllint --xpath "//response/result/key/text()" - <<<"$api_response")

# Get password hash for the new password string
password_hash_response=$(get_password_hash)
check_for_errors "$password_hash_response" "get_password_hash"
PASS_HASH=$(xmllint --xpath "//response/result/phash/text()" - <<<"$password_hash_response")

# uses the API_KEY and new password hash to updated the password of the account 
update_response=$(updated_password)
check_for_errors "$update_response" "update_password"
update_status=$(xmllint --xpath "//response/@status" - <<<"$update_response")

# commit the changes
commit_response=$(commit)
check_for_errors "$commit_response" "commit"
commit_status=$(xmllint --xpath "//response/@status" - <<<"$commit_response")
job_id=$(xmllint --xpath "//response/result/job/text()" - <<<"$commit_response")

sleep 5
# check job status
job_status=$(get_job_status "$job_id")
job_status=$(xmllint --xpath "//response/@status" - <<<"$commit_response")
printf "Completed with %s" "$job_status"





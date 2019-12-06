#!/bin/bash

function status (){
  echo " Usage: $0 <repo-file-name> <tags-filename>"
  exit 1
}

if [ -z "$2" ]
  then
    status
fi

## Capture DTR Info
[ -z "$DTR_HOSTNAME" ] && read -p "Enter the DTR hostname and press [ENTER]:" DTR_HOSTNAME
[ -z "$DTR_USER" ] && read -p "Enter the DTR username and press [ENTER]:" DTR_USER
[ -z "$DTR_PASSWORD" ] && read -s -p "Enter the DTR token or password and press [ENTER]:" DTR_PASSWORD
echo "***************************************\\n"

REPOSITORIES_FILE=$1
TAGS_FILE=$2
: > $2

TOKEN=$(curl -kLsS -u ${DTR_USER}:${DTR_PASSWORD} "https://${DTR_HOSTNAME}/auth/token" | jq -r '.token')
CURLOPTS=(-kLsS -H 'accept: application/json' -H 'content-type: application/json' -H "Authorization: Bearer ${TOKEN}")

## Read repositories file
repo_list=$(cat ${REPOSITORIES_FILE} | jq -c -r '.[]') 

# Loop through repositories
while IFS= read -r row ; do
    namespace=$(echo "$row" | jq -r .namespace)
    reponame=$(echo "$row" | jq -r .name)

    tags=$(curl -ksLS -u ${DTR_USER}:${DTR_PASSWORD} -X GET "https://$DTR_HOSTNAME/api/v0/repositories/${namespace}/${reponame}/tags?pageSize=100000000")
    tags_list=$(echo $tags | jq -c -r '.[]')
    if [ -z "$tags_list" ]
        then
            continue
    fi
    echo "Repository ==> Org: ${namespace}/${reponame}"
    while IFS= read -r tag ; do
        tagname=$(echo "$tag" | jq -r .name)
        echo ${namespace}/${reponame}:${tagname} >> $TAGS_FILE
    done <<< "$tags_list"
    
done <<< "$repo_list"
echo "=========================================\\n"

sort $TAGS_FILE > sorted-${TAGS_FILE}

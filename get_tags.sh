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

tag_count=0
# Loop through repositories
while IFS= read -r row ; do
    namespace=$(echo "$row" | jq -r .namespace)
    reponame=$(echo "$row" | jq -r .name)

    tags=$(curl -ksLS -u ${DTR_USER}:${DTR_PASSWORD} -X GET "https://$DTR_HOSTNAME/api/v0/repositories/${namespace}/${reponame}/tags?pageSize=100000000")

    tag_headers=$(curl -ks -I -u ${DTR_USER}:${DTR_PASSWORD} -X GET "https://$DTR_HOSTNAME/api/v0/repositories/${namespace}/${reponame}/tags?pageSize=1&count=true")
    tag_count=$(echo "$tag_headers" | grep 'X-Resource-Count:' | sed 's/[^0-9]*//g')
    tag_count=$(($tag_count + $tag_count))

    tags_list=$(echo $tags | jq -c -r '.[]')

    if [[ $tag_count == 0 ]]
        then
            echo "Skipping..."
    else
        while IFS= read -r tag ; do
            tagname=$(echo "$tag" | jq -r .name)
            echo ${namespace}/${reponame}:${tagname} >> $TAGS_FILE
        done <<< "$tags_list"
    fi
    echo "Repository ==> Org: ${namespace}/${reponame} ==> TagCount: $tag_count"
done <<< "$repo_list"
echo "=========================================\\n"

sort $TAGS_FILE > sorted-${TAGS_FILE}

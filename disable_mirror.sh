#!/bin/bash

function status (){
  echo " Usage: $0 <repo-file-name>"
  exit 1
}

if [ -z "$1" ]
  then
    status
fi

## Capture DTR Info
[ -z "$DTR_HOSTNAME" ] && read -p "Enter the DTR hostname and press [ENTER]:" DTR_HOSTNAME
[ -z "$DTR_USER" ] && read -p "Enter the DTR username and press [ENTER]:" DTR_USER
[ -z "$DTR_PASSWORD" ] && read -s -p "Enter the DTR token or password and press [ENTER]:" DTR_PASSWORD
echo ""
echo "***************************************\\n"


TOKEN=$(curl -kLsS -u ${DTR_USER}:${DTR_PASSWORD} "https://${DTR_HOSTNAME}/auth/token" | jq -r '.token')
CURLOPTS=(-kLsS -H 'accept: application/json' -H 'content-type: application/json' -H "Authorization: Bearer ${TOKEN}")

## comment if repository info should be extracted from a file
repos=$(curl -ks -u ${DTR_USER}:${DTR_PASSWORD} -X GET "https://${DTR_HOSTNAME}/api/v0/repositories?pageSize=100000&count=true" -H "accept: application/json" | jq -r -c .repositories)
repo_num=$(echo $repos | jq 'length')
echo "Number of Repos: $repo_num"
repo_list=$(echo "${repos}" | jq -c -r '.[]')
## Read from repositories file
#REPOSITORIES_FILE=repositories.json
#repo_list=$(cat ${REPOSITORIES_FILE} | jq -c -r '.[]') 

REPO_MIRROR_COUNT=1000
pending=0
# Loop through repositories
while IFS= read -r row ; do
    namespace=$(echo "$row" | jq -r .namespace)
    reponame=$(echo "$row" | jq -r .name)
    status="Not Enabled"

    ## Get existing mirroring policies
    pollMirroringPolicies=$(curl "${CURLOPTS[@]}" -X GET \
        "https://${DTR_HOSTNAME}/api/v0/repositories/${namespace}/${reponame}/pollMirroringPolicies")
    
    policies_num=$(echo $repos | jq 'length')
    policies=$(echo $pollMirroringPolicies | jq -c -r '.[]')
    while IFS= read -r policy; do
      if [ ! -z "$policy" ]; then
        id=$(echo $policy | jq -r .id)

        enabled=$(echo $policy | jq -r .enabled)
        if [ "x$enabled" == "xtrue" ]
        then
            ## Mirror is active on the policy 
            ## Disable mirror
            postdata=$(echo { \"enabled\": false })
            response=$(curl "${CURLOPTS[@]}" -X PUT -d "$postdata" \
                "https://${DTR_HOSTNAME}/api/v0/repositories/${namespace}/${reponame}/pollMirroringPolicies/${id}")
            echo "Repo: ${namespace}/${reponame}, PolicyId: ${id}, Setting to inactive..."
        else
            echo "Repo: ${namespace}/${reponame}, PolicyId: ${id}, Mirror not active..."
        fi
      else
        echo "Repo: ${namespace}/${reponame} Does not have any policies"
      fi
    done <<< "$policies"
done <<< "$repo_list"
echo "=========================================\\n"


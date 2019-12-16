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

REPOSITORIES_FILE=$1
REPO_MIRROR_COUNT=2

TOKEN=$(curl -kLsS -u ${DTR_USER}:${DTR_PASSWORD} "https://${DTR_HOSTNAME}/auth/token" | jq -r '.token')
CURLOPTS=(-kLsS -H 'accept: application/json' -H 'content-type: application/json' -H "Authorization: Bearer ${TOKEN}")

## Read repositories file
repo_list=$(cat ${REPOSITORIES_FILE} | jq -c -r '.[]') 

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
        id=$(echo $policy | jq -r .id)
        enabled=$(echo $policy | jq -r .enabled)
        if [ $enabled == "true" ]
        then
            lastStatus=$(echo $policy | jq -r .lastStatus.code)
            if [[ $lastStatus == "SUCCESS" ]]
            then
                status=COMPLETE
            else
                status=Pending
                pending=$((pending+1))
            fi
        elif [ $enabled == "false" ] && [ $pending -le $REPO_MIRROR_COUNT ]
        then
            postdata=$(echo { \"enabled\": true })
            response=$(curl "${CURLOPTS[@]}" -X PUT -d "$postdata" \
                "https://${DTR_HOSTNAME}/api/v0/repositories/${namespace}/${reponame}/pollMirroringPolicies/${id}")
            status=Enabling
            pending=$((pending+1))
        fi

        echo "Repo: ${namespace}/${reponame}, PolicyId: ${id}, Enabled: ${enabled} ==> Status: ${status}"
        id=
        enabled=
        status=
    done <<< "$policies"
done <<< "$repo_list"
echo "=========================================\\n"


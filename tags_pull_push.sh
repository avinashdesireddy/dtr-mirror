#!/bin/bash

function status (){
  echo " Usage: $0 <missing-tags>"
  exit 1
}

if [ -z "$1" ]
  then
    status
fi

## Capture DTR Info
[ -z "$DTR_HOSTNAME" ] && read -p "Enter the DTR hostname and press [PULL DTR]:" DTR_HOSTNAME

[ -z "$REMOTE_DTR_HOSTNAME" ] && read -p "Enter REMOTE DTR hostname and press [PUSH DTR]:" REMOTE_DTR_HOSTNAME

docker login $REMOTE_DTR_HOSTNAME

REPOSITORIES_FILE=$1

for line in `cat $REPOSITORIES_FILE`
do
    docker pull ${DTR_HOSTNAME}/${line}
    docker tag ${DTR_HOSTNAME}/${line} ${REMOTE_DTR_HOSTNAME}/${line}
    docker push ${REMOTE_DTR_HOSTNAME}/${line}
    echo "Complete: ${line}"
done

for line in `cat $REPOSITORIES_FILE`
do
    docker image rm ${DTR_HOSTNAME}/${line}
    docker image rm ${REMOTE_DTR_HOSTNAME}/${line}
done

echo "=========== COMPLETE =============\\n"


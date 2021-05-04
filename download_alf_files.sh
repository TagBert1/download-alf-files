#!/bin/bash

USERNAME=$1
PASSWORD=$2
INPUT=$3
HOST=localhost:8080
ALF_SERVICE_URL=https://${USERNAME}:${PASSWORD}@${HOST}/alfresco/service/


DOWNLOADED_FILE_FOLER=alfresco-files

mkdir -p $DOWNLOADED_FILE_FOLER


[ ! -f $INPUT ] && { echo "$INPUT file not found"; exit 99; }

while read nodeId
do

	FILE_NAME=$(curl --location --request GET "${ALF_SERVICE_URL}api/node/workspace/SpacesStore/${nodeId}/metadata" | jq -r '.name') 

	echo $FILE_NAME


	curl -s --location --request GET "${ALF_SERVICE_URL}api/node/content/workspace/SpacesStore/${nodeId}}" --output ${DOWNLOADED_FILE_FOLER}/${FILE_NAME}

done < $INPUT

IFS=$OLDIFS




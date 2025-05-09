#!/bin/bash
while getopts "f:g:s:u:r:t:d:" option;
    do
    case "$option" in
        f ) SRC_FOLDER=${OPTARG};;
        g ) GITHUB_WORKSPACE=${OPTARG};;
        s ) SOURCE_LOCATION=${OPTARG};;
        u ) AZ_ACR_NAME=${OPTARG};;
        r ) REPOSITORY=${OPTARG};;
        t ) TASKNAME=${OPTARG};;
        d ) DOCKER_FILE=${OPTARG};;
        #a ) AZURE_CREDENTIALS=${OPTARG};;
    esac
done
echo $SRC_FOLDER
echo $GITHUB_WORKSPACE
echo $SOURCE_LOCATION
echo $AZ_ACR_NAME
echo $REPOSITORY
echo $TASKNAME
echo $DOCKER_FILE

set -euxo pipefail  # fail on error
  
# Generate an tag with a reproducible checksum of all files in . by doing a checksum of all files
# in alphabetical order, then another checksum of their names and checksums.
# Running this command on windows-based infrastructure may return a different result due to CRLF
pushd $GITHUB_WORKSPACE/$SRC_FOLDER/$SOURCE_LOCATION
imageTag=$(git log -n 1 --format="%H" -- ".")
popd

## Parse JSON
#clientId=$(echo "$AZURE_CREDENTIALS" | jq -r .clientId)
#clientSecret=$(echo "$AZURE_CREDENTIALS" | jq -r .clientSecret)
#tenantId=$(echo "$AZURE_CREDENTIALS" | jq -r .tenantId)
#subscriptionId=$(echo "$AZURE_CREDENTIALS" | jq -r .subscriptionId)

## Azure CLI login using service principal
#az login --service-principal \
#  --username "$clientId" \
#  --password "$clientSecret" \
#  --tenant "$tenantId"

## Set the subscription (Azure best practice)
#az account set --subscription "$subscriptionId"

# If the image with the generated tag doesn't already exist, build it.
if ! az acr repository show -n $AZ_ACR_NAME --image "$REPOSITORY:$imageTag" -o table; then
    echo No match found. Container will be built.
    echo Tag for new container: $imageTag
    az acr build \
        -r $AZ_ACR_NAME \
        -t "$REPOSITORY:$imageTag" \
        -t "$REPOSITORY:latest" \
        -f "$GITHUB_WORKSPACE/$SRC_FOLDER/$SOURCE_LOCATION/$DOCKER_FILE" \
        $GITHUB_WORKSPACE/$SRC_FOLDER/$SOURCE_LOCATION
else
    echo "The existing image with tag "$imageTag" is found."
fi
set +x
echo "setting IMAGE_TAG output for task $TASKNAME"
echo "##vso[task.setvariable variable=IMAGE_TAG;isOutput=true]$imageTag"

# write a file containing the image tag
mkdir -p $GITHUB_WORKSPACE/image_tags      
echo "$imageTag" > $GITHUB_WORKSPACE/image_tags/$TASKNAME

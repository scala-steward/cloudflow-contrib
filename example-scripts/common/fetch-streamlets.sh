#! /bin/bash

APPLICATION=$1
if [ -z "$APPLICATION" ]; then
    echo "No application name specified."
    exit 1
fi

RUNTIME=$2
if [ -z "$RUNTIME" ]; then
    echo "No runtime specified."
    exit 1
fi

rm -rf ".tmp/${APPLICATION}"
mkdir -p ".tmp/${APPLICATION}"

CR_FILE=".tmp/${APPLICATION}/cr.json"
echo "current directory: $(pwd)"
echo "cat $CR_FILE"
cat $CR_FILE
CR_FILE_PWD=$(pwd)/$CR_FILE
echo "cat $CR_FILE_PWD"
cat $(pwd)/$CR_FILE

kubectl get cloudflowapplications.cloudflow.lightbend.com --namespace "$APPLICATION" -o json > "${CR_FILE}"

cat $CR_FILE | true

jq -rc ".items[] | select(.metadata.name == \"${APPLICATION}\") | .spec.deployments[] | select(.runtime == \"${RUNTIME}\")" "${CR_FILE}" | \
  while IFS='' read streamlet; do
    streamlet_name=$(echo "$streamlet" | jq -r '.streamlet_name')
    secret_name=$(echo "$streamlet" | jq -r '.secret_name')
    # echo "Streamlet: $streamlet_name"

    mkdir -p ".tmp/${APPLICATION}/$streamlet_name"
    echo "$streamlet" > ".tmp/${APPLICATION}/${streamlet_name}/streamlet.json"

    SECRET_FILE=".tmp/${APPLICATION}/${streamlet_name}/secret.json"
    kubectl get secret "$secret_name" --namespace "$APPLICATION" -o json > "${SECRET_FILE}"
    jq -rc ".data | keys[]" "${SECRET_FILE}" | \
      while IFS='' read secret_data; do
        # echo "Secret: $secret_data"
        mkdir -p ".tmp/${APPLICATION}/${streamlet_name}/secrets"
        jq -rc ".data.\"${secret_data}\" | @base64d" "${SECRET_FILE}" > ".tmp/${APPLICATION}/${streamlet_name}/secrets/${secret_data}"
      done
  done

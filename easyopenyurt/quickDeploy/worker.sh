#!/bin/bash

echo "Local system name: $HOSTNAME"

# Build easy_openyurt
git clone https://github.com/flyinghorse0510/easy_openyurt.git
cd easy_openyurt/src/easy_openyurt/
chmod +x ./build.sh && ./build.sh

cd bin

./easy_openyurt-aarch64-linux-0.2.4 system worker init

# Read the contents of the masterKey.yaml file
while IFS= read -r line; do
  # Check if the line contains a colon (:) to split key and value
  if [[ $line == *:* ]]; then
    key=$(echo "$line" | awk -F: '{gsub(/^[ \t]+|[ \t]+$/, "", $1); print $1}')
    value=$(echo "$line" | awk -F: '{gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}')
    
    # Trim leading and trailing spaces from the value
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    
    # Check if the key and value are not empty
    if [[ ! -z "$key" && ! -z "$value" ]]; then
      # Assign the key-value pair as a Bash variable
      declare "$key=$value"
    fi
  fi
done < "masterKey.yaml"

./easy_openyurt-aarch64-linux-0.2.4 kube worker join -apiserver-advertise-address $ApiserverAdvertiseAddress -apiserver-token $ApiserverToken -apiserver-token-hash $ApiserverTokenHash

echo -n "Kube worker JOINED"
echo

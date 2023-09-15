#!/bin/bash

## ./script.sh masterNode workers.txt

# Configure Master 
ssh -T $masterSSH < master.sh

# Copy the API keys for joining worker nodes
scp $masterSSH:~/easy_openyurt/src/easy_openyurt/bin/masterKey.yaml . 

# Configure all workers in workers.txt
while read -r node || [ -n "$node" ]; do
  scp masterKey.yaml $node:~/easy_openyurt/src/easy_openyurt/bin/
  ssh -T "$node" < worker.sh 
done < "$2"

## Openyurt ##
echo 
echo -n "---------OPENYURT-------"
echo

# OpenYurt config for master node 
ssh -T $workerSSH '~/easy_openyurt/src/easy_openyurt/bin/easy_openyurt-aarch64-linux-0.2.4 yurt master init'

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
      echo $value
    fi
  fi
done < "masterKey.yaml"

# OpenYurt config for worker nodes
while read -r node || [ -n "$node" ]; do
  ssh -T $node "~/easy_openyurt/src/easy_openyurt/bin/easy_openyurt-aarch64-linux-0.2.4 yurt worker join -apiserver-advertise-address $ApiserverAdvertiseAddress -apiserver-token $ApiserverToken"
  # ssh -nT $node 'hostname' >> hostnames.txt
done < "$2"

# On master get hostname of workers, yurt master expand
ssh -T $masterSSH <<EOL
  kubectl get nodes | 'NR > 1 && \$3 != "control-plane" {print \$1}' > output.txt
  ~/easy_openyurt/src/easy_openyurt/bin/easy_openyurt-aarch64-linux-0.2.4 yurt master expand --worker-node-name $(cat output.txt)
EOL

echo -n "Do you want to carry on with Knative (y/n)"
read knat

case $knat in
  y | yes)
    ssh -T $workerSSH '~/easy_openyurt/src/easy_openyurt/bin/easy_openyurt-aarch64-linux-0.2.4 knative master init'        
    ;;
  *)
    echo "Skipping knative init"
    ;;
esac
#!/bin/bash

echo "Local system name: $HOSTNAME"

# Build easy_openyurt
git clone https://github.com/flyinghorse0510/easy_openyurt.git
cd easy_openyurt/src/easy_openyurt/
chmod +x ./build.sh && ./build.sh

cd bin

./easy_openyurt-aarch64-linux-0.2.4 system master init
./easy_openyurt-aarch64-linux-0.2.4 kube master init

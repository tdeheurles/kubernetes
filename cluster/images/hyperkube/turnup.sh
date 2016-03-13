#!/bin/bash

# Copyright 2015 The Kubernetes Authors All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Useful for testing images and changes, turns up a fresh single node cluster

set -o errexit
set -o nounset
set -o pipefail

K8S_VERSION=${K8S_VERSION:-"1.2.0-beta.0"}

SYSTEMCTL=$(which systemctl)
if [[ $? == 0 ]];then
    echo "docker.service should reset MountFlags= (defaults to shared, but docker sets it by default to MountFlags=slave)"
    echo "documentation can be found here: https://github.com/docker/docker/blob/master/contrib/init/systemd/docker.service"
    
    read -p "Do you want that $0 do it for you ? [Y/N]"
    if [[ ${REPLY} =~ ^[Yy]$ 
          && -f /etc/systemctl/system/docker.service ]]
    then
        sudo sed -e "s/MountFlags=slave/MountFlags=shared/g"
        sudo systemctl daemon-reload
    else
        echo "Unable to find docker.service, exiting"
        exit 1
    fi
fi

mount --bind /var/lib/kubelet /var/lib/kubelet
mount --make-shared /var/lib/kubelet

# start kubelet, etcd, apiserver, controller-manager, kube-proxy
docker run \
  --volume=/:/rootfs:ro \
  --volume=/sys:/sys:ro \
  --volume=/var/lib/docker/:/var/lib/docker:rw \
  --volume=/var/lib/kubelet/:/var/lib/kubelet:shared \
  --volume=/var/run:/var/run:rw \
  --net=host \
  --pid=host \
  --privileged=true \
  -d gcr.io/google_containers/hyperkube-amd64:v${K8S_VERSION} \
  /hyperkube kubelet \
    --hostname-override="127.0.0.1" \
    --address="0.0.0.0" \
    --api-servers=http://localhost:8080 \
    --config=/etc/kubernetes/manifests \
    --cluster-dns=10.0.0.10 \
    --cluster-domain=cluster.local \
    --allow-privileged=true \
    --v=2

#!/bin/bash

images=(
    cockpit/kubernetes
    openshift/origin-control-plane
    openshift/origin-deployer
    openshift/origin-docker-registry
    openshift/origin-haproxy-router
    openshift/origin-node
    openshift/origin-pod
    openshift/origin-service-catalog
    openshift/origin-template-service-broker
    openshift/origin-web-console
)
#for image in ${images[@]}; do echo $image; done && exit

# pull images
for image in ${images[@]}; do docker pull $image; done

# push to local registry
for image in ${images[@]}
do
    image_name=$(docker images | grep "${image}" | awk '{print $1}')
    image_tag=$(docker images | grep "${image}" | awk '{print $2}')
    docker tag ${image_name}:${image_tag} 127.0.0.1/${image_name}:${image_tag}
    docker push 127.0.0.1/${image_name}:${image_tag}
    docker rmi 127.0.0.1/${image_name}:${image_tag}
done

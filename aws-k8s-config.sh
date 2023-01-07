#!/bin/bash
#setup aws s3 access
rsync -r ~/workspace/projects/paas_platform/profile/.aws ~/

aws s3 cp s3://k8s-1-22-oci/k8s-tarball.tar.gz ./

tar -x -z -f ./k8s-tarball.tar.gz -C ./tarball

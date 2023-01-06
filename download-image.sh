#!/usr/bin/env sh

#should be run in folder addon/images
for img in `cat imageList.txt`
do
  img_tar=`echo $img.tar.gz | sed 's/\//_/g' | sed 's/:/_/g'`
  if [ ! -f $img_tar ]; then
    docker pull $img
    docker image save $img | gzip > $img_tar
  fi
done

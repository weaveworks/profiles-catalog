#!/bin/bash
# Script to sort the layers and classify profiles by layers
#

set -eu
set -o pipefail

CHART_DIR=./charts/
CT_CONFIG=ct.yaml

charts=$(ls -d $CHART_DIR/*)

#Added to clear config for runner
rm -rf /tmp/layer*

touch /tmp/layers
for dir in $charts; do
  if [[ $(yq e '.annotations."weave.works/layer"' $dir/Chart.yaml) != "null" ]]; then
    echo $(yq e '.annotations."weave.works/layer"' $dir/Chart.yaml) >> /tmp/layers
  fi
done
sort /tmp/layers | uniq > /tmp/layers-sorted

cat /tmp/platforms | while read platform || [[ -n $platform ]];
do
  #Added to clear config for runner
  rm -rf /tmp/$platform*
  
  cat /tmp/layers-sorted | while read layer || [[ -n $layer ]];
  do
     echo Platform: $platform Layer: $layer
     for dir in $charts; do
       if [[ $(yq e '.annotations."weave.works/profile-ci"|contains("'$platform'")' $dir/Chart.yaml) = "true" ]] &&  $(yq e '.annotations."weave.works/layer"|contains("'$layer'")' $dir/Chart.yaml) = "true" ]]; then
         echo $dir >> /tmp/$layer-$platform
       fi
     done
  done
done

changed=$(ct list-changed --config $CT_CONFIG)
echo $changed
cat /tmp/platforms | while read platform || [[ -n $platform ]];
do
  touch /tmp/$platform-top-layer-changed
  for dir in $changed; do
    echo Found changed: $dir
    if [[ $(yq e '.annotations."weave.works/profile-ci"|contains("'$platform'")' $dir/Chart.yaml) = "true" ]]; then
      layer=$(yq e '.annotations."weave.works/layer"' $dir/Chart.yaml)
      top=$(cat /tmp/$platform-top-layer-changed)
      echo $dir >> /tmp/$layer-$platform-changed
      echo "::set-output name=$platform-ci::true"

      # checks if the layer is not set and skips if it is not
      if [[ "$layer" != "null" ]]; then
        if [[ $top = "" || "$top" < "$layer" ]]; then
            echo "$layer is lexicographically greater then $top."
            echo $layer > /tmp/$platform-top-layer-changed
        fi
      fi
    fi
  done
  echo top layer changed
  cat /tmp/$platform-top-layer-changed
done
#!/bin/bash
# Script to sort the layers and classify profiles by layers
#
CHART_DIR=./charts/
PLATFORM=kind

cat /tmp/layers-sorted | while read layer || [[ -n $layer ]];
do
  charts_in_layer=$(cat /tmp/$layer-$PLATFORM)
  [ -f /tmp/$layer-$PLATFORM-changed ] && charts_changed_in_layer=$(cat /tmp/$layer-$PLATFORM-changed)
  if [ -f /tmp/$layer-$PLATFORM-changed ]; then
    echo Testing changed in layer: $layer
    ct install --config ct.yaml --charts $(awk '{print $1}' /tmp/$layer-$PLATFORM-changed | paste -s -d, -)
    if [[ $layer < $top ]]; then
      echo Installing layer: $layer
      for dir in $charts_in_layer; do
        release=${dir##*/}
        helm dependency build  $dir
        helm install -n wego-system $release $dir
      done
    fi
  fi

done
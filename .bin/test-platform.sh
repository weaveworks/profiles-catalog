#!/bin/bash
# Script to sort the layers and classify profiles by layers
#
CHART_DIR=./charts/

cat /tmp/layers-sorted | while read layer || [[ -n $layer ]];
do
  charts_in_layer=$(cat /tmp/$layer-$INFRASTRUCTURE)
  [ -f /tmp/$layer-$INFRASTRUCTURE-changed ] && charts_changed_in_layer=$(cat /tmp/$layer-$INFRASTRUCTURE-changed)
  if [ -f /tmp/$layer-$INFRASTRUCTURE-changed ]; then
    echo Testing changed in layer: $layer
    ct install --config ct.yaml --charts $(awk '{print $1}' /tmp/$layer-$INFRASTRUCTURE-changed | paste -s -d, -)
    if [[ $layer < $top ]]; then
      echo Installing layer: $layer
      for dir in $charts_in_layer; do
        release=${dir##*/}
        helm dependency build  $dir
        helm install -n wego-system $release $dir
    fi
  fi

done
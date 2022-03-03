#!/bin/bash
# Scripts tests layer by layer
#

set -eu
set -o pipefail

CHART_DIR=./charts/

if [ "$1" != "" ]; then
    INFRASTRUCTURE=$1
    echo testing platform: $INFRASTRUCTURE
else
    echo please pass infrastructure variable
    echo example: test-platform.sh kind
    exit 1
fi

cat /tmp/layers-sorted | while read layer || [[ -n $layer ]];
do
  echo current layer is $layer
  if [ -f /tmp/$layer-$INFRASTRUCTURE ]; then 
    charts_in_layer=$(cat /tmp/$layer-$INFRASTRUCTURE)
    [ -f /tmp/$layer-$INFRASTRUCTURE-changed ] && charts_changed_in_layer=$(cat /tmp/$layer-$INFRASTRUCTURE-changed)
    if [ -f /tmp/$layer-$INFRASTRUCTURE-changed ]; then
      echo Testing changed on $INFRASTRUCTURE in layer: $layer
      ct install --config ct.yaml --charts $(awk '{print $1}' /tmp/$layer-$INFRASTRUCTURE-changed | paste -s -d, -)
    fi
    top=$(cat /tmp/$INFRASTRUCTURE-top-layer-changed)
    echo the top layer is $top
    if [[ "$top" > "$layer" ]]; then
      echo Installing layer: $layer
      for dir in $charts_in_layer; do
        release=${dir##*/}
        helm dependency build  $dir
        echo Helm install: $release
        helm install -n wego-system $release $dir
      done
    else
      echo $layer is after $top
    fi
  fi
done
# Tests profiles without a layer
if [[ -f "/tmp/null-$INFRASTRUCTURE-changed" ]]; then
  ct install --config ct.yaml --charts $(awk '{print $1}' /tmp/null-$INFRASTRUCTURE-changed | paste -s -d, -)
fi

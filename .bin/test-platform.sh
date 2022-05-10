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

TLC_FILE="/tmp/$INFRASTRUCTURE-top-layer-changed"
[ -f $TLC_FILE ] && top=$(cat $TLC_FILE) || echo "no top layer file '$TLC_FILE'"
[ -n "$top" ] && echo "the top layer changed is $top"

cat /tmp/layers-sorted | while read layer || [[ -n $layer ]];
do
  echo current layer is $layer
  if [ -f /tmp/$layer-$INFRASTRUCTURE ]; then 
    CHARTS_CHANGED_FILE="/tmp/$layer-$INFRASTRUCTURE-changed "
    if [ -f /tmp/$layer-$INFRASTRUCTURE-changed ]; then
      echo "Testing changes on $INFRASTRUCTURE in layer: $layer"
      charts_changed_in_layer=$(cat /tmp/$layer-$INFRASTRUCTURE-changed)
      ct install --config ct.yaml --charts $(awk '{print $1}' /tmp/$layer-$INFRASTRUCTURE-changed | paste -s -d, -)
    else
      echo "No changes to test on $INFRASTRUCTURE in layer $layer"
    fi
    if [[ -n "$top" && "$top" > "$layer" ]]; then
      echo "Installing layer: $layer"
      charts_in_layer=$(cat /tmp/$layer-$INFRASTRUCTURE)
      echo "Installing charts for layer $layer: ( $charts_in_layer )"
      for dir in $charts_in_layer; do
        release=${dir##*/}
        helm dependency build  $dir
        echo Helm install: $release
        helm install -n wego-system $release $dir
      done
    else
      [ -n "$top" ] && echo "$layer is after $top"
    fi
  fi
done
# Tests profiles without a layer
NO_LAYERS_FILE="/tmp/null-$INFRASTRUCTURE-changed"
if [[ -f $NO_LAYERS_FILE ]]; then
  CHARTS_TO_TEST=$(awk '{print $1}' /tmp/null-$INFRASTRUCTURE-changed | paste -s -d, -)
  echo "Testing charts without layers ( $CHARTS_TO_TEST )"
  ct install --config ct.yaml --charts $CHARTS_TO_TEST
else
  echo "No charts without layers to test - file not found $NO_LAYERS_FILE"
fi

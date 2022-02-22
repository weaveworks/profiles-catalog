#!/bin/bash
# Script to sort the layers and classify profiles by layers
#
CHART_DIR=../charts/

charts=$(ls -d $CHART_DIR/*)
touch /tmp/layer-0-ci
yq  -V
for dir in $charts; do
  if [[ $(yq e '.annotations."weave.works/layer"|contains("layer-0")' $dir/Chart.yaml) = "true" ]]; then
    echo $dir >> /tmp/layer-0-ci
  fi
done
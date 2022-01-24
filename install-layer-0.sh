#!/usr/bin/env bash
charts=$(ls -d charts/*)
touch /tmp/layer-0-ci
for dir in $charts; do
  if [[ $(yq e '.annotations."weave.works/layer"|contains("layer-0")' $dir/Chart.yaml) = "true" ]]; then
    echo $dir >> /tmp/layer-0-ci
  fi
done
cat /tmp/layer-0-ci 
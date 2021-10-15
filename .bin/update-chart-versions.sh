PROFILE_VERSION_ANNOTATION=$1

for f in $(ls */profile.yaml); do
    CHART_URLS=$(yq e '.spec.artifacts.[].chart.url | select(. != null)' ${PWD}/${f})
    CHART_NAMES=$(yq e '.spec.artifacts.[].chart.name | select(. != null)' ${PWD}/${f})
    INDEX=0
    for i in ${CHART_URLS[@]}; do
        URL=$i    
        CHART=${CHART_NAMES[$INDEX]}
        ((INDEX++))
        helm repo add temp-repo $i --force-update        
        LATEST_VERSION=$(helm search repo temp-repo/$CHART -o yaml | yq e '.[0].version' -)
        if [ $(yq e "(.spec.artifacts[] | select(.chart.name == \"$CHART\")).chart.version" ${PWD}/${f}) != $LATEST_VERSION ]; then
            yq e -i "(.spec.artifacts[] | select(.chart.name == \"$CHART\")).chart.version = \"$LATEST_VERSION\"" ${PWD}/${f}
            VERSION=$(yq e ".metadata.annotations.\"$PROFILE_VERSION_ANNOTATION\"" ${PWD}/${f})
            NEXTVERSION=$(echo ${VERSION} | awk -F. -v OFS=. '{$NF++;print}')
            yq e -i ".metadata.annotations.\"$PROFILE_VERSION_ANNOTATION\" = \"$NEXTVERSION\"" ${PWD}/${f}
        fi
    done
done
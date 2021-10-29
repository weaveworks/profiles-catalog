helm upgrade linkerd2 \
    --set installNamespace=false \
    --set identity.issuer.scheme=kubernetes.io/tls \
    linkerd/linkerd2 \
    --post-renderer ./hook.sh --debug \
    --create-namespace \
    -n linkerd
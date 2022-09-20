# EKS Add-ons profile for weave gitops
This profile is based on the provided tools (cluster-autoscaler, alb controller, aws node terminiation controller) for EKS.

This profile requires configuration depending on your cluster details and provides only the basic required items in the values.yaml. Additional configuration can be found in the following places

- https://github.com/kubernetes-sigs/aws-load-balancer-controller/blob/main/helm/aws-load-balancer-controller/values.yaml
- https://github.com/aws/aws-node-termination-handler
# Install Crossplane for AWS

Crossplane uses the AWS user credentials that were configured in the previous step to create resources in AWS. These credentials will be stored as a secret in Kubernetes, and will be used by an AWS ProviderConfig instance. To store the AWS credentials as a secret, run:
```
# retrieve profile's credentials, save it under 'default' profile, and base64 encode it
BASE64ENCODED_AWS_ACCOUNT_CREDS=$(echo -e "[default]\naws_access_key_id = $(aws configure get aws_access_key_id --profile $aws_profile)\naws_secret_access_key = $(aws configure get aws_secret_access_key --profile $aws_profile)" | base64  | tr -d "\n")

cat > secret.yaml <<EOF
---
apiVersion: v1
kind: Secret
metadata:
  name: aws-account-creds
  namespace: crossplane-system
type: Opaque
data:
  credentials: ${BASE64ENCODED_AWS_ACCOUNT_CREDS}
EOF

# apply it to the cluster:
kubectl apply -f "secret.yaml"

# delete the credentials variable
unset BASE64ENCODED_AWS_ACCOUNT_CREDS
```

For more information, please visit [Crossplane documentation](https://crossplane.io/docs/v1.4/cloud-providers/aws/aws-provider.html).
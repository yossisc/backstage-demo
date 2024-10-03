#!/bin/bash

set -e

rm -f .env

gum style  --foreground 212 --border-foreground 212 --border normal --margin "1 2" --padding "1 2" \
'Create Kubernetes clusters in Civo with Pulumi'

echo "
# This script will create a Kubernetes cluster in Civo using Pulumi

## Prerequisites

You will need following tool installed:

| Name       | Required | More info                                           |
|------------|----------|-----------------------------------------------------|
| Pulumi CLI | Yes      | \`https://www.pulumi.com/docs/iac/download-install/\` |
" | gum format
echo ""
gum confirm "Do you have Pulumi installed?" || exit 0

echo "
## Pulumi Authentication

To create Kubernetes clusters in Civo, you'll need to provide your Pulumi access token. You can generate one by following the instructions here: \`https://www.pulumi.com/docs/pulumi-cloud/access-management/access-tokens/\`.

Please enter your Pulumi access token below:
" | gum format

cd iac/civo-cluster
rm -f .env

PULUMI_ACCESS_TOKEN=$(gum input --placeholder "Enter Pulumi access token" --value "$PULUMI_ACCESS_TOKEN" --password)
echo "export PULUMI_ACCESS_TOKEN=$PULUMI_ACCESS_TOKEN" > $(pwd)/.env
echo ""
echo "
## Civo Authentication

To create Kubernetes clusters in Civo, you'll need to provide your Civo access token. You can generate one by following the instructions here: \`https://www.civo.com/docs/account/api-keys\` or use the one provided by the workshop organizers.
" | gum format

CIVO_TOKEN=$(gum input --placeholder "Civo token" --value "$CIVO_TOKEN" --password)
echo "export CIVO_TOKEN=$CIVO_TOKEN" >>  $(pwd)/.env
echo ""

source  .env
pulumi stack init dev || true
pulumi stack select dev
pulumi up -y -f
pulumi stack output kubeconfig --show-secrets > kubeconfig.yaml

export KUBECONFIG=$(pwd)/kubeconfig.yaml
echo "export KUBECONFIG=$(pwd)/kubeconfig.yaml" >> $(pwd)/.env

kubectl get nodes

echo ""

echo "
-> Head over to the next chapter by running the \`./demo.sh\` script
" | gum format

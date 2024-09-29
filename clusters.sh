#!/bin/sh

set -e

gum style \
        --foreground 212 --border-foreground 212 --border double \
        --margin "1 2" --padding "2 4" \
        'Create Kubernetes clusters in Civo with Pulumi'

echo "
## You will need following tools installed:
|Name            |Required             |More info                                          |
|----------------|---------------------|---------------------------------------------------|
|civo CLI        |No                  |'https://github.com/civo/cli'                      |
|Pulumi CLI         |Yes                 |'https://www.pulumi.com/docs/iac/download-install/'|
" | gum format

gum confirm "Do you have those tools installed?" || exit 0
gum style --foreground 212 --width 250 'To create Kubernetes clusters in Civo, we need to first login to Pulumi'
gum confirm "Do you want to login to Pulumi?" && pulumi login || exit 0

cd iac/civo-cluster

CIVO_TOKEN=$(gum input --placeholder "Civo token" --value "$CIVO_TOKEN" --password)
echo "export CIVO_TOKEN=$CIVO_TOKEN" > .env

source .env

pulumi up -y -f -s dev

pulumi stack output kubeconfig --show-secrets -s dev> kubeconfig.yaml

#export KUBECONFIG=$(pwd)/kubeconfig.yaml
echo "export KUBECONFIG=$(pwd)/kubeconfig.yaml" >> $(pwd)/.env

kubectl get nodes

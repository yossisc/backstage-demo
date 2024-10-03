#!/bin/bash

set -e

gum style \
        --foreground 212 --border-foreground 212 --border normal --margin "1 2" --padding "1 2" \
        'Destroy Kubernetes clusters in Civo with Pulumi'

echo "
# This script will destroy a Kubernetes cluster in Civo using Pulumi

## Prerequisites

You will need following tool installed:

| Name       | Required | More info                                           |
|------------|----------|-----------------------------------------------------|
| Pulumi CLI | Yes      | \`https://www.pulumi.com/docs/iac/download-install/\` |
" | gum format
echo ""
gum confirm "Do you have Pulumi installed?" || exit 0

#gum style --foreground 212 --width 250 'To delete the Kubernetes clusters in Civo, we need to first login to Pulumi'
#gum confirm "Do you want to login to Pulumi?" && pulumi login || exit 0

echo "
All other needed information will be read from the .env file, which was created during the cluster creation process.

Do you want to continue?
" | gum format
echo ""
gum confirm "Do you want to continue?" || exit 0

cd iac/civo-cluster
source .env

pulumi stack select dev
pulumi destroy -y -f

rm -f kubeconfig.yaml

rm -f apps/*.yaml

rm -f infra/*.yaml

git add .

git commit -m "Destroy"

git push


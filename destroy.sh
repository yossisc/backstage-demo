#!/bin/sh

set -e

gum style \
        --foreground 212 --border-foreground 212 --border double \
        --margin "1 2" --padding "2 4" \
        'Destroy Kubernetes clusters in Civo with Pulumi'

echo "
## You will need following tools installed:
|Name            |Required             |More info                                          |
|----------------|---------------------|---------------------------------------------------|
|civo CLI        |No                  |'https://github.com/civo/cli'                      |
|Pulumi CLI         |Yes                 |'https://www.pulumi.com/docs/iac/download-install/'|
" | gum format

gum confirm "Do you have those tools installed?" || exit 0
gum style --foreground 212 --width 250 'To delete the Kubernetes clusters in Civo, we need to first login to Pulumi'
gum confirm "Do you want to login to Pulumi?" && pulumi login || exit 0

cd iac/civo-cluster

source .env

pulumi destroy -y -f

rm -f kubeconfig.yaml


rm apps/*.yaml

rm infra/*.yaml

git add .

git commit -m "Destroy"

git push

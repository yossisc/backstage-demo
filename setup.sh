#!/bin/bash

set -e

rm -f .env

cp iac/civo-cluster/.env .

source .env

gum style \
        --foreground 212 --border-foreground 212 --border double \
        --margin "1 2" --padding "2 4" \
        'Backstage Demo Setup'

echo "
## You will need following tools installed:
|Name            |Required             |More info                                          |
|----------------|---------------------|---------------------------------------------------|
|gum             |Yes                  |'https://github.com/charmbracelet/gum'             |
|gitHub CLI      |Yes                  |'https://cli.github.com/'                          |
|yq              |Yes                  |'https://github.com/mikefarah/yq#install'          |
|kubeseal        |Yes                  |'https://github.com/bitnami-labs/sealed-secrets#kubeseal'|
|Helm            |Yes                  |'https://github.com/helm/helm#install'             |
|kubectl         |Yes                  |'https://github.com/kubernetes/kubectl'            |
|argocd-cli      |Yes                  |'https://argo-cd.readthedocs.io/en/stable/cli_installation/'|
" | gum format

gum confirm "
Do you have those tools installed?
" || exit 0


#gum confirm "Do you want to use an organizational GitHub account?" && USE_GH_ORG=true || USE_GH_ORG=false

#if $USE_GH_ORG ; then
#    GITHUB_ORG=$(gum input \
#    --placeholder "Which GitHub organization do you want to use?" \
#    --value "$GITHUB_ORG")

 #   gh repo fork dirien/backstage-demo --clone --remote \
 #       --org $GITHUB_ORG
#else
#    GITHUB_ORG=$(gum input \
#    --placeholder "What's your GitHub user name?" \
#    --value "$GITHUB_ORG")

#    gh repo fork dirien/backstage-demo --clone --remote
#fi

#echo "export GITHUB_ORG=$GITHUB_ORG" >> .env

#echo "export GITHUB_ORG=dirien" >> .env
GITHUB_ORG=$(gum input --placeholder "Which GitHub organization/user do you want to use?" --value "GITHUB_ORG")
echo "export GITHUB_ORG=$GITHUB_ORG" >>  .env

#cd backstage-demo

#export INGRESS_CLASS=$(kubectl get ingressclasses \
#    --output jsonpath="{.items[0].metadata.name}")
#echo "export INGRESS_CLASS=$INGRESS_CLASS" >> .env

#WORKAROUND: Because of an issue with Civo to install Traefik as part of the cluster creation, we need to install it manually
kubectl apply -f https://raw.githubusercontent.com/civo/kubernetes-marketplace/refs/heads/master/traefik2-loadbalancer/app.yaml

ip=""
while [ -z $ip ]; do
  echo "Waiting for external IP"
  ip=$(kubectl get svc traefik --namespace kube-system --template="{{range .status.loadBalancer.ingress}}{{.ip}}{{end}}")
  [ -z "$ip" ] && sleep 10
done
echo 'Found external IP: '$ip

export INGRESS_HOST=$(\
    kubectl --namespace kube-system get service traefik \
    --output jsonpath="{.status.loadBalancer.ingress[0].ip}")
echo "export INGRESS_HOST=$INGRESS_HOST" >> .env

#yq --inplace \
#    ".server.ingress.ingressClassName = \"$INGRESS_CLASS\"" \
#    argocd/helm-values.yaml

yq --inplace \
    ".server.ingress.hostname = \"argocd.$INGRESS_HOST.nip.io\"" \
    argocd/helm-values.yaml

yq --inplace \
    ".spec.source.repoURL = \"https://github.com/$GITHUB_ORG/backstage-demo\"" \
    argocd/production-apps.yaml

yq --inplace \
    ".spec.source.repoURL = \"https://github.com/$GITHUB_ORG/backstage-demo\"" \
    argocd/production-infra.yaml

yq --inplace \
    ".spec.source.repoURL = \"https://github.com/$GITHUB_ORG/backstage-demo\"" \
    argocd/users-api.yaml

yq --inplace \
    ".spec.sources[0].repoURL = \"https://github.com/$GITHUB_ORG/backstage-demo\"" \
    argocd/backstage.yaml

yq --inplace \
    ".spec.sources[2].repoURL = \"https://github.com/$GITHUB_ORG/backstage-demo\"" \
    argocd/backstage.yaml

gum style \
        --foreground 212 --border-foreground 212 --border double \
        --margin "1 2" --padding "2 4" \
        'Create a token in GitHub - https://github.com/settings/tokens' \
        'or by navigating to Settings -> Developer Settings (left panel) ->' \
        'Personal Access Token -> Tokens (Classic) -> Generate new token' \
        '' \
        'Required permissions:' \
        '  - repo' \
        '  - read:org' \
        '  - read:user' \
        '  - user:email' \
        '  - workflow'

GITHUB_TOKEN=$(gum input --placeholder "GitHub token" --value "$GITHUB_TOKEN" --password)
echo "export GITHUB_TOKEN=$GITHUB_TOKEN" >> .env

#yq --inplace \
#    ".data.ARGOCD_URL = \"http://argocd.$INGRESS_HOST.nip.io/api/v1/\"" \
#    backstage-resources/bs-config.yaml

yq --inplace \
    ".backstage.backstage.extraEnvVars |= map(select(.name == \"ARGOCD_URL\").value = \"http://argocd.$INGRESS_HOST.nip.io/api/v1/\")" \
    backstage-resources/helm-values.yaml

#yq --inplace \
#    ".data.CATALOG_LOCATION = \"https://github.com/$GITHUB_ORG/backstage-demo/blob/main/catalog/catalog-all.yaml\"" \
#    backstage-resources/bs-config.yaml

yq --inplace \
    ".backstage.backstage.extraEnvVars |= map(select(.name == \"CATALOG_LOCATION\").value = \"https://github.com/$GITHUB_ORG/backstage-demo/blob/main/catalog/catalog-all.yaml\")" \
    backstage-resources/helm-values.yaml

export BACKSTAGE_URL="backstage.$INGRESS_HOST.nip.io"
echo "export BACKSTAGE_URL=$BACKSTAGE_URL" >> .env

#yq --inplace ".data.BASE_URL = \"$BACKSTAGE_URL\"" \
#    backstage-resources/bs-config.yaml

yq --inplace \
    ".backstage.ingress.host = \"$BACKSTAGE_URL\"" \
    backstage-resources/helm-values.yaml

yq --inplace \
    ".backstage.backstage.extraEnvVars |= map(select(.name == \"BASE_URL\").value = \"$BACKSTAGE_URL\")" \
    backstage-resources/helm-values.yaml

echo "
Deploying ArgoCD
" | gum format

###########
# Argo CD #
###########

helm upgrade --install argocd argo-cd \
    --repo https://argoproj.github.io/argo-helm \
    --namespace argocd --create-namespace \
    --values argocd/helm-values.yaml --wait

echo "http://argocd.$INGRESS_HOST.nip.io"

# Open the URL from the output in a browser
# Use `admin` as the user and `admin123` as the password

cat argocd/production-apps.yaml

cat argocd/production-infra.yaml

kubectl apply --filename argocd/production-infra.yaml

kubectl apply --filename argocd/production-apps.yaml

export ARGOCD_ADMIN_PASSWORD=admin123

argocd login --insecure --port-forward --insecure \
    --username admin --password $ARGOCD_ADMIN_PASSWORD \
    --port-forward-namespace argocd --grpc-web --plaintext

# Generate API auth token for ArgoCD
export ARGOCD_AUTH_TOKEN=$(argocd account generate-token \
    --port-forward --port-forward-namespace argocd)

export ARGOCD_AUTH_TOKEN_ENCODED="argocd.token=$ARGOCD_AUTH_TOKEN"
echo "export ARGOCD_AUTH_TOKEN_ENCODED=$ARGOCD_AUTH_TOKEN_ENCODED" >> .env

echo "export ARGOCD_URL=http://argocd.$INGRESS_HOST.nip.io" >> .env

echo "
Setup Done!

Please Make Sure You Can Access ArgoCD UI:

ArgoCD NIP http://argocd.$INGRESS_HOST.nip.io 
Username: admin
Password: admin123

" | gum format

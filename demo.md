## Demo

Here you will find all the steps to build on the results from `cluster.sh` and `setup.sh`. If you did not run the
previous scripts, you should run them before starting this one.

### Prerequisites

Read the `.env` file and make sure you have all the required environment variables set.

```bash
source .env
```

Do not leave the terminal where you sourced the `.env` file, as we will use the environment variables in the following
steps and also use the output from some steps to continue with the next ones.

### PostgresSQL

First, we will deploy CloudNativePG operator to the cluster. This operator will take care to deploy a PostgreSQL
instance for our Backstage application.

```bash
cat argocd/cnpg.yaml

cp argocd/cnpg.yaml infra/.

git add infra

git commit -m "CPNG"

git push
```

> Observe CNPG rollout in Argo CD UI

```bash
kubectl --namespace cnpg-system get all

cat argocd/backstage-postgresql.yaml

cp argocd/backstage-postgresql.yaml infra/.

git add .

git commit -m "Backstage PostgreSQL"

git push
```

> Observe PostgreSQL rollout in Argo CD UI

Check the status of the PostgreSQL deployment and get the password for the database.

```bash
kubectl --namespace backstage get clusters

# The the login credentials for Backstage

export DB_PASS=$(kubectl --namespace backstage \
get secret backstage-app \
--output jsonpath="{.data.password}" | base64 --decode)

# Wait for the DB to be created
kubectl --namespace backstage wait pod backstage-1 \
--for=condition=Ready --timeout=90s

# Repeat the previous command if it errored claiming that the
#   Pod does not exist since that probably means that the Pod
#   was not yet created.

kubectl exec -it --namespace=backstage backstage-1 -- \
psql -c "\du"
```

### SealedSecrets

Now we will deploy the SealedSecrets controller to the cluster.

```bash
cat argocd/sealed-secrets-app.yaml

cp argocd/sealed-secrets-app.yaml infra/.

git add infra

git commit -m "Deploy sealed secrets controller"

git push
```

> Observe SealedSecrets rollout in Argo CD UI

### Backstage

Next, we will deploy Backstage to the cluster. For this, we will create a secret with the required environment variables
and use the sealed secret controller to encrypt it so we can check it into the repository and let Argo CD deploy it.

```bash
cat backstage-resources/*.yaml

kubectl --namespace backstage \
create secret generic backstage-secrets \
--from-literal POSTGRES_USER=app \
--from-literal POSTGRES_PASSWORD=$DB_PASS \
--from-literal GITHUB_TOKEN=$GITHUB_TOKEN \
--from-literal ARGOCD_AUTH_TOKEN=$ARGOCD_AUTH_TOKEN_ENCODED \
--dry-run=client --output json

kubectl --namespace backstage \
create secret generic backstage-secrets \
--from-literal POSTGRES_USER=app \
--from-literal POSTGRES_PASSWORD=$DB_PASS \
--from-literal GITHUB_TOKEN=$GITHUB_TOKEN \
--from-literal ARGOCD_AUTH_TOKEN=$ARGOCD_AUTH_TOKEN_ENCODED \
--dry-run=client --output yaml \
| kubeseal --controller-namespace kubeseal --format yaml \
| tee backstage-resources/bs-secret.yaml

cat argocd/backstage.yaml

#yq --inplace \
#    ".spec.rules[0].host = \"backstage.$INGRESS_HOST.nip.io\"" \
#    backstage-resources/bs-ingress.yaml

cp argocd/backstage.yaml infra/.

git add .

git commit -m "Deploy Backstage"

git push

# Observe the Backstage rollout in ArgoCD

kubectl --namespace backstage get all,secrets

echo "https://$BACKSTAGE_URL"
```

> Open the URL from the output in a browser

### Deploy Users API App

Now we will deploy the Users API application to the cluster.

```bash
cat users-api/deployment.yaml

cat argocd/users-api.yaml

cp argocd/users-api.yaml apps/.

git add .

git commit -m "deploy users-api"

git push

kubectl get all
```

### Add Users API to the Catalog

As a final step, we will add the Users API to the Backstage catalog.

```bash
cat users-api/users-app-component.yaml

cp users-api/users-app-component.yaml catalog/

yq --inplace \
".spec.targets += \"./users-app-component.yaml\"" \
catalog/catalog-all.yaml

git add catalog

git commit -m "add users-api to the catalog"

git push
```

> Head over top Backstage and check the new component in the catalog and how the Kubernetes and Argo CD plugins work.

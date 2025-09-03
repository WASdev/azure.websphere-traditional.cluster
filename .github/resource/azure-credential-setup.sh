#!/usr/bin/env bash
# Copyright (c) IBM Corporation.
# Copyright (c) Microsoft Corporation.

set -Eeuo pipefail

CURRENT_FILE_NAME="azure-credential-setup.sh"
echo "Execute $CURRENT_FILE_NAME - Start------------------------------------------"

## Create Azure Credentials
REPO_NAME=$(basename `git rev-parse --show-toplevel`)
AZURE_CREDENTIALS_SP_NAME="sp-${REPO_NAME}-$(date +%s)"
echo "Creating Azure Service Principal with name: $AZURE_CREDENTIALS_SP_NAME"
AZURE_SUBSCRIPTION_ID=$(az account show --query id -o tsv| tr -d '\r\n')
AZURE_CREDENTIALS=$(az ad sp create-for-rbac --name "$AZURE_CREDENTIALS_SP_NAME" --role owner --scopes /subscriptions/"$AZURE_SUBSCRIPTION_ID" --sdk-auth)
SP_ID=$(az ad sp list --display-name $AZURE_CREDENTIALS_SP_NAME --query [0].id -o tsv)
# Assign Privileged Role Administrator role to the Service Principal
# https://learn.microsoft.com/entra/identity/role-based-access-control/permissions-reference#all-roles
az rest -m POST \
  --uri 'https://graph.microsoft.com/v1.0/directoryRoles/roleTemplateId=e8611ab8-c189-46e8-94e1-60213ab1f814/members/$ref' \
  --body "{\"@odata.id\":\"https://graph.microsoft.com/v1.0/directoryObjects/${SP_ID}\"}"

## Set the Azure Credentials as a secret in the repository
gh secret --repo $(gh repo set-default --view) set "AZURE_CREDENTIALS" -b"${AZURE_CREDENTIALS}"
gh variable --repo $(gh repo set-default --view)  set "AZURE_CREDENTIALS_SP_NAME" -b"${AZURE_CREDENTIALS_SP_NAME}"

echo "Execute $CURRENT_FILE_NAME - End--------------------------------------------"

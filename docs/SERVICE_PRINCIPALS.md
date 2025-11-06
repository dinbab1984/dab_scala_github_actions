# Service Principal Configuration

This document explains the service principal setup for deploying and running Databricks jobs.

## Overview

We use **two separate service principals** for better security and separation of concerns:

1. **Deployment Service Principal** (`deployment_sp`): Used for deploying the bundle
2. **Runtime Service Principal** (`run_as_sp`): Used for executing the job

## Why Two Service Principals?

### Security Benefits

1. **Principle of Least Privilege**: Each service principal has only the permissions it needs
2. **Separation of Concerns**: Deployment and runtime have different security requirements
3. **Audit Trail**: Separate identities make it easier to track who did what
4. **Risk Mitigation**: If one SP is compromised, the other remains secure
5. **Compliance**: Many organizations require separation between deployment and execution identities

### Permission Differences

| Capability | Deployment SP | Runtime SP |
|------------|---------------|------------|
| Create/Update Jobs | ✅ Yes | ❌ No |
| Delete Jobs | ✅ Yes | ❌ No |
| Modify Cluster Config | ✅ Yes | ❌ No |
| Run Jobs | ❌ No* | ✅ Yes |
| Read Unity Catalog Data | ❌ No* | ✅ Yes |
| Write to Azure Storage | ❌ No* | ✅ Yes |
| Access Azure Key Vault | ❌ No* | ✅ Yes |

*The deployment SP doesn't need runtime permissions

## Configuration

### In Variables (`databricks/variables.yml`)

```yaml
variables:
  deployment_sp:
    description: "Service principal name for deploying the bundle (bundle deployment)"
    default: "sp-dev-deployment"
  
  run_as_sp:
    description: "Service principal name for running the job (job execution runtime)"
    default: "sp-dev-runtime"
```

### In Targets (`databricks/targets.yml`)

```yaml
targets:
  dev:
    variables:
      deployment_sp: "sp-dev-deployment"
      run_as_sp: "sp-dev-runtime"
    
    # Used for bundle deployment operations
    run_as:
      service_principal_name: "${var.deployment_sp}"
```

### In Job Resources (`databricks/resources/dbxload_job.yml`)

```yaml
resources:
  jobs:
    dbxload_worker:
      # Used for job execution
      run_as:
        service_principal_name: "${var.run_as_sp}"
```

## Required Permissions

### Deployment Service Principal

**Databricks Workspace Permissions**:
- `CAN_MANAGE` on the workspace folder where jobs are deployed
- `CAN_USE` on cluster policies
- `CAN_CREATE` jobs
- `CAN_ATTACH_TO` clusters (for validation)

**Unity Catalog Permissions** (minimal):
- `USE CATALOG` on the catalog (for validation)
- `USE SCHEMA` on deployment schema

**Azure Permissions**:
- None required (deployment only)

### Runtime Service Principal

**Databricks Workspace Permissions**:
- None required (runs as job identity)

**Unity Catalog Permissions**:
- `USE CATALOG` on the catalog
- `USE SCHEMA` on required schemas
- `SELECT`, `MODIFY` on tables as needed
- `READ VOLUME`, `WRITE VOLUME` on volumes

**Azure Permissions**:
- **Storage Account**: `Storage Blob Data Contributor`
- **Azure Queue**: `Storage Queue Data Contributor`
- **Azure Table**: `Storage Table Data Contributor`
- **Key Vault**: `Key Vault Secrets User`

## Setup Instructions

### Step 1: Create Service Principals in Azure AD

```bash
# Create deployment service principal
az ad sp create-for-rbac \
  --name "sp-${ENV}-deployment" \
  --role "Contributor" \
  --scopes /subscriptions/${SUBSCRIPTION_ID}

# Create runtime service principal
az ad sp create-for-rbac \
  --name "sp-${ENV}-runtime" \
  --role "Contributor" \
  --scopes /subscriptions/${SUBSCRIPTION_ID}
```

Save the output (client_id, client_secret, tenant_id) securely.

### Step 2: Register in Databricks

```bash
# Add deployment SP to Databricks
databricks service-principals create \
  --display-name "sp-${ENV}-deployment" \
  --application-id ${DEPLOYMENT_CLIENT_ID}

# Add runtime SP to Databricks
databricks service-principals create \
  --display-name "sp-${ENV}-runtime" \
  --application-id ${RUNTIME_CLIENT_ID}
```

### Step 3: Grant Databricks Permissions

**For Deployment SP**:
```bash
# Grant workspace permissions
databricks permissions set jobs \
  --service-principal-name "sp-${ENV}-deployment" \
  --permission-level CAN_MANAGE

# Grant cluster policy permissions
databricks permissions set cluster-policies ${POLICY_ID} \
  --service-principal-name "sp-${ENV}-deployment" \
  --permission-level CAN_USE
```

**For Runtime SP**:
```bash
# Grant Unity Catalog permissions
databricks grants update catalog ${CATALOG_NAME} \
  --principal "sp-${ENV}-runtime" \
  --privilege "USE_CATALOG"

databricks grants update schema ${CATALOG_NAME}.${SCHEMA_NAME} \
  --principal "sp-${ENV}-runtime" \
  --privilege "USE_SCHEMA"

databricks grants update volume ${CATALOG_NAME}.${SCHEMA_NAME}.${VOLUME_NAME} \
  --principal "sp-${ENV}-runtime" \
  --privilege "READ_VOLUME,WRITE_VOLUME"
```

### Step 4: Grant Azure Permissions

**For Runtime SP** (Deployment SP needs no Azure permissions):

```bash
# Storage Account
az role assignment create \
  --assignee ${RUNTIME_CLIENT_ID} \
  --role "Storage Blob Data Contributor" \
  --scope /subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG}/providers/Microsoft.Storage/storageAccounts/${STORAGE_ACCOUNT}

# Queue permissions
az role assignment create \
  --assignee ${RUNTIME_CLIENT_ID} \
  --role "Storage Queue Data Contributor" \
  --scope /subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG}/providers/Microsoft.Storage/storageAccounts/${STORAGE_ACCOUNT}

# Key Vault
az keyvault set-policy \
  --name ${KEY_VAULT_NAME} \
  --spn ${RUNTIME_CLIENT_ID} \
  --secret-permissions get list
```

### Step 5: Update Configuration

Edit `databricks/targets.yml`:

```yaml
targets:
  dev:
    variables:
      deployment_sp: "sp-dev-deployment"
      run_as_sp: "sp-dev-runtime"
```

### Step 6: Configure CI/CD Secrets

Add to GitHub Secrets:

**Deployment SP** (for bundle deployment):
- `AZURE_CLIENT_ID_DEV` = Deployment SP client ID
- `AZURE_CLIENT_SECRET_DEV` = Deployment SP client secret

**Runtime SP** (automatically used by job):
- The job will use `run_as_sp` which is configured in Databricks

## Authentication in CI/CD

### GitHub Actions (OIDC - Recommended)

```yaml
- name: Azure Login for Deployment
  uses: azure/login@v1
  with:
    client-id: ${{ secrets.AZURE_CLIENT_ID_DEV }}  # Deployment SP
    tenant-id: ${{ secrets.AZURE_TENANT_ID }}
    subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID_DEV }}

- name: Deploy Bundle
  run: databricks bundle deploy -t dev
  env:
    DATABRICKS_HOST: ${{ secrets.DATABRICKS_HOST_DEV }}
    DATABRICKS_TOKEN: ${{ secrets.DATABRICKS_TOKEN_DEV }}
```

### Local Development

Configure `.databrickscfg` with deployment SP:

```ini
[dev]
host = https://adb-xxxxx.azuredatabricks.net
auth_type = azure-client-secret
azure_tenant_id = your-tenant-id
azure_client_id = your-deployment-sp-client-id
azure_client_secret = your-deployment-sp-secret
```

The runtime SP is automatically used when the job runs.

## Validation

### Test Deployment SP

```bash
# Should succeed - deployment SP can deploy
databricks bundle deploy -t dev

# Should succeed - can create/update jobs
databricks jobs list

# Should fail - deployment SP shouldn't run jobs directly
# (This is expected - jobs run as runtime SP)
```

### Test Runtime SP

The runtime SP is tested when the job runs:

```bash
# Trigger job run
databricks bundle run dbxload_worker -t dev

# Check job logs for:
# - Successful Azure Storage access
# - Successful Unity Catalog access
# - Proper identity (should show runtime SP)
```

## Troubleshooting

### "Service principal not found" Error

**Problem**: `Service principal 'sp-dev-runtime' not found`

**Solution**:
1. Verify SP exists in Databricks:
   ```bash
   databricks service-principals list | grep sp-dev-runtime
   ```
2. If missing, create it:
   ```bash
   databricks service-principals create \
     --display-name "sp-dev-runtime" \
     --application-id ${CLIENT_ID}
   ```

### "Insufficient permissions" During Deployment

**Problem**: Deployment fails with permission error

**Solution**: Grant deployment SP workspace permissions:
```bash
databricks permissions set jobs \
  --service-principal-name "sp-dev-deployment" \
  --permission-level CAN_MANAGE
```

### "Access denied" During Job Execution

**Problem**: Job fails with Azure access denied

**Solution**: Grant runtime SP Azure permissions:
```bash
az role assignment create \
  --assignee ${RUNTIME_CLIENT_ID} \
  --role "Storage Blob Data Contributor" \
  --scope ${STORAGE_ACCOUNT_SCOPE}
```

### "Cannot read Unity Catalog" Error

**Problem**: Job can't read catalog/schema/volume

**Solution**: Grant runtime SP Unity Catalog permissions:
```bash
databricks grants update volume ${CATALOG}.${SCHEMA}.${VOLUME} \
  --principal "sp-dev-runtime" \
  --privilege "READ_VOLUME,WRITE_VOLUME"
```

## Security Best Practices

1. **Rotate Secrets Regularly**: Change SP secrets every 90 days
2. **Use Azure Key Vault**: Store secrets in Key Vault, not in code
3. **Implement RBAC**: Use Azure RBAC for fine-grained permissions
4. **Monitor Access**: Enable Azure AD audit logs
5. **Least Privilege**: Grant only necessary permissions
6. **Separate Environments**: Use different SPs for dev/staging/prod
7. **Document Changes**: Keep this document updated
8. **Use Managed Identity**: Consider Managed Identity where possible (Azure-hosted runners)

## Environment-Specific Configuration

### Development
- Deployment SP: `sp-dev-deployment`
- Runtime SP: `sp-dev-runtime`
- More permissive (for debugging)
- May use same SP in dev if needed

### Staging
- Deployment SP: `sp-staging-deployment`
- Runtime SP: `sp-staging-runtime`
- Production-like permissions
- Separate from dev and prod

### Production
- Deployment SP: `sp-prod-deployment`
- Runtime SP: `sp-prod-runtime`
- Strictly scoped permissions
- Heavily monitored and audited
- Requires approval for deployment

## References

- [Databricks Service Principals](https://docs.databricks.com/dev-tools/auth/service-principals.html)
- [Azure AD Service Principals](https://docs.microsoft.com/en-us/azure/active-directory/develop/app-objects-and-service-principals)
- [Unity Catalog Permissions](https://docs.databricks.com/data-governance/unity-catalog/manage-privileges/index.html)
- [Azure RBAC](https://docs.microsoft.com/en-us/azure/role-based-access-control/overview)


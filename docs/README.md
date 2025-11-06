# Databricks Asset Bundle - DBXLoad Worker Job

This directory contains the Databricks Asset Bundle (DAB) configuration for the DBXLoad Worker job.

## Overview

The DBXLoad Worker is a multi-task Databricks job that:
1. **JobSetup**: Initializes the job configuration and environment
2. **LoadItemProducer**: Produces load items to the queue
3. **LoadItemExecutor_Loop**: Executes load items in parallel using for-each task

## Project Structure

The configuration is modular and split across multiple files for better maintainability:

```
ct_lib/
├── databricks.yml                          # Main bundle configuration (entry point)
├── databricks/
│   ├── variables.yml                       # All bundle variables
│   ├── targets.yml                         # Environment configurations (dev/staging/prod)
│   ├── resources/
│   │   └── dbxload_job.yml                # Job resource definition
│   ├── deploy.sh                          # Deployment helper script
│   ├── .env.template                      # Environment variables template
│   ├── README.md                          # This file
│   └── STRUCTURE.md                       # Detailed structure documentation
├── .databrickscfg.template                # Databricks CLI config template
├── .github/
│   └── workflows/
│       └── databricks-deploy.yml          # CI/CD pipeline
└── libs/_6_lakehouseDBXJob/               # Source code
```

**Configuration Files**:
- **`databricks.yml`**: Main entry point with bundle name and includes
- **`databricks/variables.yml`**: All variables with defaults and descriptions
- **`databricks/targets.yml`**: Environment-specific configurations
- **`databricks/resources/dbxload_job.yml`**: Complete job definition

See [STRUCTURE.md](STRUCTURE.md) for detailed information about the modular configuration.

**Note**: We use built-in `${bundle.target}` for environment names instead of custom variables. See [BUILTIN_VARIABLES.md](BUILTIN_VARIABLES.md) for details.

## Prerequisites

1. **Databricks CLI** (v0.213.0 or later)
   ```bash
   curl -fsSL https://raw.githubusercontent.com/databricks/setup-cli/main/install.sh | sh
   ```

2. **Databricks Workspace** with:
   - Unity Catalog enabled
   - **Two Service Principals configured**:
     - Deployment SP (for bundle deployment)
     - Runtime SP (for job execution)
   - Cluster policies set up
   - Volumes created for artifact storage
   
   See [SERVICE_PRINCIPALS.md](SERVICE_PRINCIPALS.md) for detailed setup

3. **Azure Resources**:
   - Storage Account with queues configured
   - Service Principal with appropriate permissions
   - Azure Key Vault for secrets (recommended)

4. **GitHub Secrets** configured (for CI/CD):
   - `DATABRICKS_HOST_DEV`, `DATABRICKS_HOST_STAGING`, `DATABRICKS_HOST_PROD`
   - `DATABRICKS_TOKEN_DEV`, `DATABRICKS_TOKEN_STAGING`, `DATABRICKS_TOKEN_PROD`
   - `AZURE_CLIENT_ID_*`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID_*`
   - `ARTIFACTORY_USERNAME`, `ARTIFACTORY_PASSWORD`

## Configuration

### Environment Variables

The bundle supports three environments: `dev`, `staging`, and `prod`. Each environment has its own configuration in `databricks.yml`.

Key variables that can be customized:
- `workspace_name`: Databricks workspace identifier
- `deployment_sp`: Service principal for running the job
- `catalog_name`: Unity Catalog name
- `storage_account_name`: Azure storage account
- `spark_version`: Databricks runtime version
- `node_type`: Cluster node type
- `min_workers`, `max_workers`: Autoscaling configuration

### Customizing Variables

Variables are defined in `databricks/variables.yml` with defaults. You can override them in multiple ways:

1. **Per environment** in `databricks/targets.yml`:
   ```yaml
   targets:
     dev:
       variables:
         max_workers: 8
   ```

2. **At deployment time**:
   ```bash
   databricks bundle deploy -t dev --var="max_workers=16"
   ```

3. **Using environment variables**:
   ```bash
   export DATABRICKS_BUNDLE_VAR_max_workers=16
   databricks bundle deploy -t dev
   ```

To add a new variable:
1. Add it to `databricks/variables.yml` with a default value
2. Use it in resource files with `${var.variable_name}`
3. Override per environment in `databricks/targets.yml` if needed

## Local Development

### 1. Configure Databricks CLI

Create a `.databrickscfg` file in your home directory:

```ini
[dev]
host = https://adb-xxxxx.azuredatabricks.net
token = dapi_your_token_here

[staging]
host = https://adb-yyyyy.azuredatabricks.net
token = dapi_your_token_here

[prod]
host = https://adb-zzzzz.azuredatabricks.net
token = dapi_your_token_here
```

Or use OAuth:
```bash
databricks auth login --host https://adb-xxxxx.azuredatabricks.net
```

### 2. Validate Configuration

Validate the bundle configuration:
```bash
databricks bundle validate -t dev
```

### 3. Build Artifacts

Build the JAR file:
```bash
sbt "project lakehouseDBXJob" clean package
```

### 4. Deploy to Development

```bash
# Deploy the bundle
databricks bundle deploy -t dev

# View deployment summary
databricks bundle summary -t dev
```

### 5. Run the Job

```bash
# Get the job ID
databricks bundle run dbxload_worker -t dev

# Or manually trigger
databricks jobs run-now --job-id <job-id>
```

## CI/CD Pipeline

The GitHub Actions workflow (`.github/workflows/databricks-deploy.yml`) automates the deployment process.

### Workflow Triggers

- **Push to `develop`**: Deploys to `dev` environment
- **Push to `main`**: Deploys to `staging` environment
- **Manual workflow dispatch**: Allows deployment to any environment (including `prod`)

### Deployment Flow

1. **Build**: Compiles and packages the JAR artifact
2. **Validate**: Validates bundle configuration for all environments
3. **Deploy**: Uploads JAR to Databricks Volume and deploys the bundle
4. **Test**: Runs smoke tests (optional)

### Manual Production Deployment

To deploy to production:
1. Go to GitHub Actions
2. Select "Deploy to Databricks" workflow
3. Click "Run workflow"
4. Select `prod` environment
5. Approve deployment (requires reviewer approval)

## Best Practices

### 1. Version Management

- Use semantic versioning for releases
- JAR artifacts include timestamp and commit hash
- Production deployments should use tagged releases

### 2. Environment Separation

- Each environment has its own workspace and resources
- Service principals are environment-specific
- No cross-environment resource sharing

### 3. Security

- Use service principals instead of user tokens
- Store secrets in Azure Key Vault
- Implement RBAC for job access
- Use SINGLE_USER cluster security mode

### 4. Cost Optimization

- Use SPOT instances with fallback
- Configure appropriate autoscaling
- Set job timeouts
- Use queue to prevent concurrent runs

### 5. Monitoring

- Enable email notifications for failures
- Use webhook notifications for integration
- Monitor job runs in Databricks UI
- Set up Azure Monitor alerts for queue depths

### 6. Disaster Recovery

- Keep bundle configurations in version control
- Document runbook for job failures
- Implement retry logic in code
- Regular backup of configuration

## Updating the Job

### Adding a New Task

1. Edit `databricks/resources/dbxload_job.yml`
2. Add task under `tasks` section
3. Define dependencies using `depends_on`
4. Validate and deploy

### Modifying Job Configuration

1. Update variables in `databricks.yml`
2. Or modify job definition in `dbxload_job.yml`
3. Validate changes: `databricks bundle validate -t dev`
4. Deploy: `databricks bundle deploy -t dev`

### Scaling Configuration

To increase parallelism:
```yaml
variables:
  max_workers: 16
  for_each_concurrency: 8
  for_each_inputs: "[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16]"
```

## Troubleshooting

### Bundle Validation Fails

```bash
# Check for syntax errors
databricks bundle validate -t dev

# View detailed error messages
databricks bundle validate -t dev --log-level debug
```

### Deployment Fails

```bash
# Check Databricks CLI configuration
databricks auth describe

# Verify permissions
databricks workspace list /Volumes/

# Check job status
databricks jobs list | grep dbxload-worker
```

### Job Fails to Run

1. Check job logs in Databricks UI
2. Verify JAR file exists in Volume
3. Check service principal permissions
4. Verify Azure Queue connectivity

### JAR Upload Fails

```bash
# Verify volume path
databricks fs ls dbfs:/Volumes/dev_catalog/deployments/pipeline/jars/

# Check permissions
databricks volumes list --catalog dev_catalog --schema deployments
```

## Additional Resources

- [Databricks Asset Bundles Documentation](https://docs.databricks.com/dev-tools/bundles/index.html)
- [Databricks CLI Reference](https://docs.databricks.com/dev-tools/cli/index.html)
- [Unity Catalog Best Practices](https://docs.databricks.com/data-governance/unity-catalog/best-practices.html)
- [Databricks Jobs API](https://docs.databricks.com/api/workspace/jobs)

## Support

For issues or questions:
- Create an issue in GitHub
- Contact: data-platform-team@contitech.com
- Internal Wiki: [Link to internal documentation]


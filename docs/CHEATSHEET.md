# Databricks Asset Bundle - Quick Reference

## Essential Commands

### Validation
```bash
# Validate configuration for an environment
databricks bundle validate -t dev
databricks bundle validate -t staging
databricks bundle validate -t prod

# Validate with debug info
databricks bundle validate -t dev --log-level debug
```

### Deployment
```bash
# Deploy to development
databricks bundle deploy -t dev

# Deploy with variable override
databricks bundle deploy -t dev --var="max_workers=16"

# Deploy with multiple overrides
databricks bundle deploy -t dev \
  --var="max_workers=16" \
  --var="for_each_concurrency=8"

# Dry run (see what would be deployed)
databricks bundle deploy -t dev --dry-run

# Use helper script
./databricks/deploy.sh -e dev -b
```

### Running Jobs
```bash
# Run the job
databricks bundle run dbxload_worker -t dev

# List jobs
databricks jobs list

# Get job ID
databricks jobs list | grep dbxload-worker

# Run job by ID
databricks jobs run-now --job-id JOB_ID

# Wait for job completion
databricks jobs wait --run-id RUN_ID
```

### Monitoring
```bash
# View deployment summary
databricks bundle summary -t dev

# List job runs
databricks jobs list-runs --job-id JOB_ID

# Get run details
databricks jobs get-run --run-id RUN_ID

# View logs
databricks jobs get-run-output --run-id RUN_ID

# Cancel a run
databricks jobs cancel-run --run-id RUN_ID
```

### Building
```bash
# Build JAR
sbt "project lakehouseDBXJob" clean package

# Build all projects
sbt clean compile package

# Run tests
sbt "project lakehouseDBXJob" test

# Find built JAR
find libs/_6_lakehouseDBXJob/target/scala-2.13 -name "*.jar"
```

## File Locations

| What | Where |
|------|-------|
| Main config | `databricks.yml` |
| Variables | `databricks/variables.yml` |
| Environments | `databricks/targets.yml` |
| Job definition | `databricks/resources/dbxload_job.yml` |
| Deploy script | `databricks/deploy.sh` |
| CI/CD pipeline | `.github/workflows/databricks-deploy.yml` |
| Documentation | `databricks/README.md` |

## Configuration Variables

### Key Variables (databricks/variables.yml)

| Variable | Description | Default |
|----------|-------------|---------|
| `workspace_name` | Workspace identifier | `dev-workspace` |
| `deployment_sp` | Deployment service principal | `sp-dev-deployment` |
| `run_as_sp` | Runtime service principal | `sp-dev-runtime` |
| `catalog_name` | Unity Catalog name | `dev_catalog` |
| `schema_name` | Schema name | `deployments` |
| `volume_name` | Volume name | `pipeline` |
| `storage_account_name` | Azure storage account | `ctdpdevdatastore` |
| `spark_version` | Databricks runtime | `17.3.x-scala2.13` |
| `node_type` | VM size | `Standard_D4ds_v5` |
| `max_workers` | Max cluster size | `8` |
| `for_each_concurrency` | Parallel executors | `4` |

### Environment-Specific Overrides (databricks/targets.yml)

**Dev:**
- `max_workers: 8`
- `jar_version: ${bundle.git.commit_timestamp}`

**Staging:**
- `max_workers: 12`
- `jar_version: ${bundle.git.tag}`

**Prod:**
- `max_workers: 16`
- `for_each_concurrency: 8`
- `jar_version: ${bundle.git.tag}`

## Variable Override Methods

### 1. In targets.yml (Permanent)
```yaml
targets:
  dev:
    variables:
      max_workers: 16
```

### 2. Command Line (One-time)
```bash
databricks bundle deploy -t dev --var="max_workers=16"
```

### 3. Environment Variable (Session)
```bash
export DATABRICKS_BUNDLE_VAR_max_workers=16
databricks bundle deploy -t dev
```

## Service Principals

| SP Type | Used For | Permissions |
|---------|----------|-------------|
| **deployment_sp** | Bundle deployment | Create/update jobs, modify clusters |
| **run_as_sp** | Job execution | Access data, Azure Storage, Unity Catalog |

Set in:
- `databricks/variables.yml` (defaults)
- `databricks/targets.yml` (per environment)

Used in:
- `databricks/targets.yml` → `run_as.service_principal_name` (deployment)
- `databricks/resources/dbxload_job.yml` → `run_as.service_principal_name` (runtime)

## Common Tasks

### Add a New Variable
```bash
# 1. Edit databricks/variables.yml
variables:
  my_new_var:
    description: "My new variable"
    default: "value"

# 2. Use in databricks/resources/dbxload_job.yml
some_config: "${var.my_new_var}"

# 3. (Optional) Override in databricks/targets.yml
targets:
  prod:
    variables:
      my_new_var: "prod_value"
```

### Change Cluster Size
```bash
# Temporary (this deployment only)
databricks bundle deploy -t dev --var="max_workers=20"

# Permanent (edit databricks/targets.yml)
targets:
  prod:
    variables:
      max_workers: 32
```

### Update JAR
```bash
# Build new JAR
sbt "project lakehouseDBXJob" clean package

# Deploy with new JAR
databricks bundle deploy -t dev
```

### View Job Configuration
```bash
# Get job ID
JOB_ID=$(databricks jobs list --output json | \
  jq -r '.jobs[] | select(.settings.name | contains("dbxload-worker")) | .job_id')

# View full configuration
databricks jobs get --job-id $JOB_ID
```

## Troubleshooting

### "Variable not defined"
```bash
# Add to databricks/variables.yml
variables:
  missing_var:
    default: "value"
```

### "Authentication failed"
```bash
# Re-authenticate
databricks auth login --host YOUR_HOST

# Or check config
cat ~/.databrickscfg
```

### "JAR not found"
```bash
# Build JAR
sbt "project lakehouseDBXJob" clean package

# Check if exists
ls libs/_6_lakehouseDBXJob/target/scala-2.13/*.jar
```

### "Permission denied"
```bash
# Check service principal permissions
databricks service-principals list | grep sp-dev

# Grant permissions
databricks permissions set jobs \
  --service-principal-name "sp-dev-deployment" \
  --permission-level CAN_MANAGE
```

### Bundle validation fails
```bash
# Validate with debug
databricks bundle validate -t dev --log-level debug

# Check YAML syntax
yamllint databricks.yml
```

## Environment Setup

### First Time Setup
```bash
# 1. Install Databricks CLI
curl -fsSL https://raw.githubusercontent.com/databricks/setup-cli/main/install.sh | sh

# 2. Configure authentication
databricks auth login --host YOUR_HOST

# 3. Update workspace ID in databricks/targets.yml

# 4. Build and deploy
sbt "project lakehouseDBXJob" clean package
databricks bundle deploy -t dev
```

### Daily Workflow
```bash
# 1. Make changes to code or config
vim databricks/variables.yml

# 2. Validate
databricks bundle validate -t dev

# 3. Deploy
databricks bundle deploy -t dev

# 4. Test
databricks bundle run dbxload_worker -t dev
```

## Useful One-Liners

```bash
# Get job ID
databricks jobs list --output json | jq -r '.jobs[] | select(.settings.name | contains("dbxload")) | .job_id'

# Get latest run ID
databricks jobs list-runs --job-id JOB_ID --output json | jq -r '.runs[0].run_id'

# Watch job run
watch -n 5 'databricks jobs get-run --run-id RUN_ID | jq .state'

# List all SPs
databricks service-principals list --output json | jq -r '.[].display_name'

# Check bundle files
find databricks -name "*.yml" -type f

# Validate all environments
for env in dev staging prod; do echo "=== $env ===" && databricks bundle validate -t $env; done

# Show configuration for environment
databricks bundle summary -t dev

# List volumes
databricks volumes list --catalog dev_catalog --schema deployments

# Upload file to volume
databricks fs cp local-file.jar dbfs:/Volumes/dev_catalog/deployments/pipeline/jars/
```

## GitHub Actions Workflow

### PR on `main` Branch

When you create a PR to `main`, the workflow automatically:
1. ✅ Runs all SBT tests
2. ✅ Builds JAR artifact
3. ✅ Validates bundle configuration
4. ✅ Deploys to dev environment
5. ✅ Uploads JAR to volume
6. ✅ Runs the job in dev
7. ✅ Posts results as PR comment

**Example PR Comment**:
```
✅ Dev Environment - Deployment and Test succeeded

**Deployment:**
- Version: `20231109-143022-a1b2c3d`
- Job: dev-dbxload-worker

**Test Run:**
- Run ID: `987654`
- Status: `TERMINATED`
- Result: `SUCCESS`

✅ All tests passed! Ready for review.
```

### GitHub Secrets Required

| Secret | Purpose |
|--------|---------|
| `DATABRICKS_HOST_DEV` | Dev workspace URL |
| `DATABRICKS_TOKEN_DEV` | Dev access token |
| `AZURE_CLIENT_ID_DEV` | Dev deployment SP client ID |
| `AZURE_TENANT_ID` | Azure AD tenant ID |
| `AZURE_SUBSCRIPTION_ID_DEV` | Azure subscription ID |
| `ARTIFACTORY_USERNAME` | SBT artifactory username |
| `ARTIFACTORY_PASSWORD` | SBT artifactory password |

## Built-in Variables

Databricks provides built-in variables you can use:

| Variable | Purpose | Example |
|----------|---------|---------|
| `${bundle.target}` | Current environment | `dev`, `staging`, `prod` |
| `${bundle.name}` | Bundle name | `ct-lakehouse-dbxload` |
| `${bundle.git.commit_timestamp}` | Commit timestamp | `1699564800` |
| `${bundle.git.tag}` | Git tag | `v1.0.0` |

See [BUILTIN_VARIABLES.md](BUILTIN_VARIABLES.md) for complete list.

## Quick Links

- **Documentation**: [README.md](README.md)
- **Quick Start**: [QUICKSTART.md](QUICKSTART.md)
- **Structure**: [STRUCTURE.md](STRUCTURE.md)
- **Built-in Variables**: [BUILTIN_VARIABLES.md](BUILTIN_VARIABLES.md)
- **Security**: [SERVICE_PRINCIPALS.md](SERVICE_PRINCIPALS.md)
- **Architecture**: [ARCHITECTURE.md](ARCHITECTURE.md)
- **Summary**: [SUMMARY.md](SUMMARY.md)

## Support

- **Team**: data-platform-team@contitech.com
- **GitHub Issues**: Create an issue
- **Databricks Docs**: https://docs.databricks.com/dev-tools/bundles/


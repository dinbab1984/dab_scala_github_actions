# Quick Start Guide

This guide will help you get started with deploying the DBXLoad Worker job using Databricks Asset Bundles.

## 🚀 Quick Deployment (5 minutes)

### Step 1: Install Databricks CLI

```bash
# macOS/Linux
curl -fsSL https://raw.githubusercontent.com/databricks/setup-cli/main/install.sh | sh

# Verify installation
databricks --version
```

### Step 2: Configure Authentication

```bash
# Option 1: OAuth (Recommended)
databricks auth login --host https://adb-xxxxx.azuredatabricks.net

# Option 2: Token-based
# Create ~/.databrickscfg with your credentials (see .databrickscfg.template)
```

### Step 3: Customize Configuration

Edit `databricks/targets.yml` and update the workspace host:

```yaml
targets:
  dev:
    workspace:
      host: https://adb-YOUR-WORKSPACE-ID.azuredatabricks.net
```

### Step 4: Build and Deploy

```bash
# Build the JAR
sbt "project lakehouseDBXJob" clean package

# Validate configuration
databricks bundle validate -t dev

# Deploy to development
databricks bundle deploy -t dev
```

### Step 5: Run the Job

```bash
# Trigger the job
databricks bundle run dbxload_worker -t dev

# Or use the deployment script
./databricks/deploy.sh -e dev -b -r
```

## 📝 Common Operations

### Deploy to Different Environments

```bash
# Deploy to development
databricks bundle deploy -t dev

# Deploy to staging
databricks bundle deploy -t staging

# Deploy to production
databricks bundle deploy -t prod
```

### Override Variables

```bash
# Deploy with custom worker count
databricks bundle deploy -t dev --var="max_workers=16"

# Deploy with multiple overrides
databricks bundle deploy -t dev \
  --var="max_workers=16" \
  --var="for_each_concurrency=8"
```

### View Deployment Status

```bash
# Show what's deployed
databricks bundle summary -t dev

# List jobs
databricks jobs list --output json | jq '.jobs[] | select(.settings.name | contains("dbxload"))'
```

### Update Configuration

1. Edit files in `databricks/`:
   - `variables.yml` - change variable defaults
   - `targets.yml` - modify environment settings
   - `resources/dbxload_job.yml` - update job definition

2. Validate changes:
   ```bash
   databricks bundle validate -t dev
   ```

3. Deploy changes:
   ```bash
   databricks bundle deploy -t dev
   ```

## 🔧 Configuration Files Explained

| File | Purpose | When to Edit |
|------|---------|--------------|
| `databricks.yml` | Main entry point | Rarely (only for bundle name or includes) |
| `databricks/variables.yml` | Variable definitions | When adding new variables |
| `databricks/targets.yml` | Environment configs | When configuring environments |
| `databricks/resources/dbxload_job.yml` | Job definition | When modifying job structure |

## 🎯 Common Tasks

### Add a New Variable

1. Edit `databricks/variables.yml`:
```yaml
variables:
  my_new_setting:
    description: "Description here"
    default: "default_value"
```

2. Use in `databricks/resources/dbxload_job.yml`:
```yaml
some_config: "${var.my_new_setting}"
```

### Change Cluster Configuration

Edit `databricks/variables.yml`:
```yaml
variables:
  spark_version:
    default: "17.3.x-scala2.13"
  
  node_type:
    default: "Standard_D4ds_v5"
  
  max_workers:
    default: 8
```

Or override per environment in `databricks/targets.yml`:
```yaml
targets:
  prod:
    variables:
      spark_version: "18.0.x-scala2.13"
      max_workers: 32
```

### Modify Task Parameters

Edit `databricks/resources/dbxload_job.yml` in the tasks section:
```yaml
tasks:
  - task_key: JobSetup
    spark_jar_task:
      parameters:
        - >-
          {
            "clazz": "JobSetup",
            "customParam": "value"
          }
```

### Scale Up/Down

For temporary scaling:
```bash
databricks bundle deploy -t dev --var="max_workers=20"
```

For permanent scaling, edit `databricks/targets.yml`:
```yaml
targets:
  prod:
    variables:
      max_workers: 32
      for_each_concurrency: 16
```

## 🐛 Troubleshooting

### "Variable not defined" Error

**Problem**: `Variable 'xyz' is not defined`

**Solution**: Add to `databricks/variables.yml`:
```yaml
variables:
  xyz:
    default: "value"
```

### "Failed to authenticate" Error

**Problem**: Can't connect to Databricks

**Solution**: 
```bash
# Re-authenticate
databricks auth login --host https://adb-xxxxx.azuredatabricks.net

# Or check ~/.databrickscfg
cat ~/.databrickscfg
```

### "JAR not found" Error

**Problem**: Job can't find the JAR file

**Solution**:
```bash
# Build the JAR
sbt "project lakehouseDBXJob" clean package

# Upload manually
databricks fs cp \
  libs/_6_lakehouseDBXJob/target/scala-2.13/lakehouse-dbx-job_*.jar \
  dbfs:/Volumes/dev_catalog/deployments/pipeline/jars/ \
  --overwrite
```

### Deployment Fails

**Problem**: Bundle deployment fails

**Solution**:
```bash
# Validate first
databricks bundle validate -t dev --log-level debug

# Check permissions
databricks workspace list /

# Try with fresh authentication
databricks auth login --host YOUR_HOST
```

## 📚 Next Steps

1. **Read Detailed Documentation**: See [README.md](README.md)
2. **Understand Structure**: See [STRUCTURE.md](STRUCTURE.md)
3. **Set Up CI/CD**: Configure GitHub Actions (see `.github/workflows/databricks-deploy.yml`)
4. **Configure Monitoring**: Set up email notifications and alerts
5. **Review Security**: Implement proper RBAC and secret management

## 🔗 Useful Commands

```bash
# Show bundle configuration
databricks bundle schema

# Validate all environments
for env in dev staging prod; do
  echo "Validating $env..."
  databricks bundle validate -t $env
done

# Deploy with dry-run
databricks bundle deploy -t dev --dry-run

# View job runs
databricks jobs list-runs --job-id JOB_ID

# View logs
databricks jobs get-run --run-id RUN_ID

# Cancel a run
databricks jobs cancel-run --run-id RUN_ID
```

## 💡 Tips

1. **Always validate before deploying**: `databricks bundle validate -t ENV`
2. **Use development mode for testing**: Development mode has relaxed permissions
3. **Tag your releases**: Use git tags for production deployments
4. **Monitor job runs**: Set up notifications for failures
5. **Use the deployment script**: `./databricks/deploy.sh` provides helpful features
6. **Keep secrets in Key Vault**: Never commit credentials
7. **Document changes**: Update this documentation when making changes

## 📞 Getting Help

- **Documentation**: See [README.md](README.md)
- **Issues**: Create a GitHub issue
- **Team**: Contact data-platform-team@contitech.com
- **Databricks Docs**: https://docs.databricks.com/dev-tools/bundles/

---

**Ready to deploy?** Run: `./databricks/deploy.sh -e dev -b`


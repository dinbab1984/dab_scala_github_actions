# Databricks Asset Bundle Structure

This document explains the modular structure of the Databricks Asset Bundle configuration.

## File Organization

The configuration is split into multiple files for better maintainability and organization:

```
ct_lib/
├── databricks.yml                          # Main bundle configuration
├── databricks/
│   ├── variables.yml                       # All bundle variables
│   ├── targets.yml                         # Environment configurations
│   ├── resources/
│   │   └── dbxload_job.yml                # Job resource definition
│   ├── deploy.sh                          # Deployment helper script
│   ├── .env.template                      # Environment variables template
│   ├── README.md                          # Comprehensive documentation
│   └── STRUCTURE.md                       # This file
├── .databrickscfg.template                # Databricks CLI config template
└── .github/
    └── workflows/
        └── databricks-deploy.yml          # CI/CD pipeline
```

## Configuration Files

### 1. `databricks.yml` (Main Configuration)

The entry point for the bundle. Contains:
- Bundle name
- Include directives to load other configuration files
- Artifacts configuration

**Purpose**: Minimal main file that orchestrates other configuration files.

**Example**:
```yaml
bundle:
  name: ct-lakehouse-dbxload

include:
  - databricks/variables.yml
  - databricks/targets.yml
  - databricks/resources/*.yml

artifacts:
  dbxload_jar:
    type: jar
    path: ./libs/_6_lakehouseDBXJob/target/scala-2.13/*.jar
    build: sbt "project lakehouseDBXJob" clean package
```

### 2. `databricks/variables.yml` (Variables)

Defines all configurable variables used across environments. Variables are organized into logical sections:

- **Deployment Configuration**: Workspace name, service principals
- **Unity Catalog Configuration**: Catalog, schema, volume names
- **Azure Storage Configuration**: Storage accounts, queue names, table names
- **Cluster Configuration**: Node types, versions, policies, scaling
- **Job Runtime Configuration**: Timeouts, retry logic, batch sizes
- **Task Configuration**: Concurrency, parallelism
- **Artifact Configuration**: Version management

**Benefits**:
- Single source of truth for all variables
- Easy to find and modify configuration values
- Clear documentation with descriptions
- Type-safe with defaults

**Example**:
```yaml
variables:
  max_workers:
    description: "Maximum number of workers"
    default: 8
  
  storage_account_name:
    description: "Azure storage account name"
    default: "ctdpdevdatastore"
```

### 3. `databricks/targets.yml` (Environments)

Defines environment-specific configurations for:
- **dev**: Development environment (mode: development)
- **staging**: Staging environment (mode: production)
- **prod**: Production environment (mode: production)

Each target includes:
- Workspace connection details
- Environment-specific variable overrides
- Service principal configuration
- Permissions and access control

**Benefits**:
- Clear separation of environments
- Environment-specific overrides
- Different scaling for different environments
- Separate permission models

**Example**:
```yaml
targets:
  dev:
    mode: development
    workspace:
      host: https://adb-xxxxx.azuredatabricks.net
    variables:
      max_workers: 8
      jar_version: "${bundle.git.commit_timestamp}"
  
  prod:
    mode: production
    workspace:
      host: https://adb-yyyyy.azuredatabricks.net
    variables:
      max_workers: 16
      jar_version: "${bundle.git.tag}"
```

### 4. `databricks/resources/dbxload_job.yml` (Job Definition)

Contains the complete job resource definition including:
- Job configuration (name, notifications, queue settings)
- Cluster configuration
- Task definitions (JobSetup, LoadItemProducer, LoadItemExecutor_Loop)
- Libraries and dependencies
- Task dependencies and execution flow

**Benefits**:
- Complete job definition in one place
- Uses variables from `variables.yml`
- Can be easily extended with more tasks
- Reusable across environments

## How Variables Work

### Variable Resolution Order

Variables are resolved in the following order (later overrides earlier):

1. **Default values** in `variables.yml`
2. **Target-specific overrides** in `targets.yml`
3. **Command-line overrides** during deployment
4. **Environment variables** with `DATABRICKS_BUNDLE_VAR_` prefix

### Using Variables

Variables can be referenced using `${var.variable_name}` syntax:

```yaml
# In dbxload_job.yml
job_cluster_key: "${var.workspace_name}-dbxload"

spark_version: "${var.spark_version}"

libraries:
  - jar: "/Volumes/${var.catalog_name}/${var.schema_name}/${var.volume_name}/jars/lakehouse-dbx-job-${var.jar_version}.jar"
```

### Overriding Variables

#### Method 1: In targets.yml
```yaml
targets:
  prod:
    variables:
      max_workers: 16
      for_each_concurrency: 8
```

#### Method 2: Command Line
```bash
databricks bundle deploy -t dev --var="max_workers=16"
```

#### Method 3: Environment Variable
```bash
export DATABRICKS_BUNDLE_VAR_max_workers=16
databricks bundle deploy -t dev
```

## Adding New Configuration

### Adding a New Variable

1. Add to `databricks/variables.yml`:
```yaml
variables:
  my_new_variable:
    description: "Description of the variable"
    default: "default_value"
```

2. Use in resource files:
```yaml
some_configuration: "${var.my_new_variable}"
```

3. (Optional) Override per environment in `targets.yml`:
```yaml
targets:
  prod:
    variables:
      my_new_variable: "prod_value"
```

### Adding a New Resource

1. Create a new file in `databricks/resources/`:
```bash
touch databricks/resources/my_new_resource.yml
```

2. Define your resource:
```yaml
resources:
  jobs:
    my_new_job:
      name: "${var.workspace_name}-my-job"
      # ... job configuration
```

3. It will be automatically included via the `include` directive in `databricks.yml`

### Adding a New Environment

1. Add to `databricks/targets.yml`:
```yaml
targets:
  qa:
    mode: production
    workspace:
      host: https://adb-xxxxx.azuredatabricks.net
    variables:
      workspace_name: "qa-workspace"
      # ... other overrides
```

2. Deploy to the new environment:
```bash
databricks bundle deploy -t qa
```

## Best Practices

### 1. **Variable Naming**
- Use snake_case for variable names
- Be descriptive and consistent
- Group related variables with prefixes (e.g., `azure_*`, `cluster_*`)

### 2. **Default Values**
- Always provide sensible defaults in `variables.yml`
- Defaults should work for development environment
- Document what the variable affects

### 3. **Environment Overrides**
- Override only what's different in each environment
- Don't repeat default values
- Use more resources in production (scaling, concurrency)

### 4. **Resource Organization**
- One resource type per file (e.g., all jobs in one file)
- Or one resource per file for complex resources
- Use descriptive file names

### 5. **Comments and Documentation**
- Add comments explaining complex configurations
- Document why certain values are chosen
- Keep README.md updated

### 6. **Version Control**
- All `.yml` files should be in git
- Never commit `.env` or `.databrickscfg` files
- Use `.gitignore` properly

## Validation

Validate your configuration at any time:

```bash
# Validate for specific environment
databricks bundle validate -t dev

# Validate with debug output
databricks bundle validate -t dev --log-level debug

# Check what would be deployed
databricks bundle deploy -t dev --dry-run
```

## Common Patterns

### Pattern 1: Environment-Specific Scaling

```yaml
# variables.yml
variables:
  max_workers:
    default: 8

# targets.yml
targets:
  prod:
    variables:
      max_workers: 32
      for_each_concurrency: 16
```

### Pattern 2: Feature Flags

```yaml
# variables.yml
variables:
  enable_experimental_feature:
    default: false

# targets.yml
targets:
  dev:
    variables:
      enable_experimental_feature: true
```

### Pattern 3: Conditional Configuration

```yaml
# Use Jinja2-like expressions (if supported)
{% if var.enable_monitoring %}
email_notifications:
  on_failure:
    - team@example.com
{% endif %}
```

## Troubleshooting

### Issue: Variable Not Found

**Error**: `Variable 'xyz' is not defined`

**Solution**: Add the variable to `databricks/variables.yml`:
```yaml
variables:
  xyz:
    default: "value"
```

### Issue: Include File Not Found

**Error**: `Failed to load include file`

**Solution**: Check the path in `include` directive. Paths are relative to the file containing the `include`.

### Issue: Circular Dependency

**Error**: `Circular include detected`

**Solution**: Don't include files that include each other. Keep includes hierarchical.

## References

- [Databricks Asset Bundles Documentation](https://docs.databricks.com/dev-tools/bundles/index.html)
- [Bundle Configuration Reference](https://docs.databricks.com/dev-tools/bundles/settings.html)
- [YAML Include Syntax](https://docs.databricks.com/dev-tools/bundles/settings.html#include-other-configuration-files)





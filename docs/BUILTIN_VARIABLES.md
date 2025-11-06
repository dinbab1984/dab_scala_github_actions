# Databricks Asset Bundle Built-in Variables

This document explains the built-in variables provided by Databricks Asset Bundles that you can use in your configuration.

## Available Built-in Variables

### `${bundle.target}`

The name of the current deployment target (environment).

**Example Values**: `dev`, `staging`, `prod`

**Usage**:
```yaml
resources:
  jobs:
    my_job:
      name: "${bundle.target}-my-job"  # Results in: dev-my-job, staging-my-job, or prod-my-job
      
      tags:
        environment: "${bundle.target}"
```

**Use Cases**:
- Naming resources with environment prefix
- Tagging resources
- Passing environment name to job parameters
- Environment-specific configurations

**Example from our configuration**:
```yaml
# Job name varies by environment
name: "${bundle.target}-dbxload-worker"
# dev → dev-dbxload-worker
# staging → staging-dbxload-worker
# prod → prod-dbxload-worker

# Job cluster key
job_cluster_key: "${bundle.target}-dbxload"

# Job parameter
parameters:
  - name: stage
    default: "${bundle.target}"

# Tags
tags:
  environment: "${bundle.target}"
```

---

### `${bundle.name}`

The name of the bundle as defined in `databricks.yml`.

**Example Value**: `ct-lakehouse-dbxload`

**Usage**:
```yaml
resources:
  jobs:
    my_job:
      name: "${bundle.name}-worker"  # Results in: ct-lakehouse-dbxload-worker
```

---

### `${bundle.git.branch}`

The current git branch name.

**Example Values**: `main`, `develop`, `feature/new-feature`

**Usage**:
```yaml
resources:
  jobs:
    my_job:
      tags:
        git_branch: "${bundle.git.branch}"
```

**Note**: Only available if the bundle is deployed from a git repository.

---

### `${bundle.git.commit}`

The full git commit SHA.

**Example Value**: `a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0`

**Usage**:
```yaml
resources:
  jobs:
    my_job:
      tags:
        git_commit: "${bundle.git.commit}"
```

---

### `${bundle.git.commit_timestamp}`

Unix timestamp of the current git commit.

**Example Value**: `1699564800`

**Usage**:
```yaml
variables:
  jar_version:
    default: "${bundle.git.commit_timestamp}"
```

**Use Case**: Version artifacts with commit timestamp for traceability.

**Example from our configuration**:
```yaml
targets:
  dev:
    variables:
      jar_version: "${bundle.git.commit_timestamp}"
      # Results in JAR name like: lakehouse-dbx-job-1699564800.jar
```

---

### `${bundle.git.tag}`

The git tag if the current commit is tagged, otherwise empty.

**Example Value**: `v1.0.0`, `release-2023-11-09`

**Usage**:
```yaml
targets:
  prod:
    variables:
      jar_version: "${bundle.git.tag}"
```

**Use Case**: Use git tags for production releases.

**Example from our configuration**:
```yaml
targets:
  prod:
    variables:
      jar_version: "${bundle.git.tag}"
      # Ensures production uses tagged releases like: lakehouse-dbx-job-v1.0.0.jar
```

---

### `${workspace.host}`

The Databricks workspace host URL for the current target.

**Example Value**: `https://adb-1234567890.azuredatabricks.net`

**Usage**:
```yaml
resources:
  jobs:
    my_job:
      tags:
        workspace: "${workspace.host}"
```

---

### `${workspace.file_path}`

The path in the Databricks workspace where bundle files are stored.

**Example Value**: `/Users/user@example.com/.bundle/ct-lakehouse-dbxload/dev`

**Usage**:
```yaml
# Typically used internally by Databricks
# Not commonly needed in user configurations
```

---

## Built-in vs Custom Variables

### Built-in Variables (No Definition Needed)
- Provided automatically by Databricks
- Available in all bundle configurations
- Cannot be overridden
- Accessed with `${bundle.*}` or `${workspace.*}`

**Examples**:
```yaml
# No definition needed - works out of the box
name: "${bundle.target}-job"
version: "${bundle.git.commit_timestamp}"
```

### Custom Variables (Must Be Defined)
- Defined in `databricks/variables.yml`
- Can have default values
- Can be overridden per environment
- Accessed with `${var.*}`

**Examples**:
```yaml
# Must be defined in variables.yml
variables:
  max_workers:
    description: "Maximum workers"
    default: 8

# Then used in resources
resources:
  jobs:
    my_job:
      max_workers: ${var.max_workers}
```

---

## Why We Use `${bundle.target}` Instead of Custom Variable

### ❌ Before (Custom Variable)
```yaml
# databricks/variables.yml
variables:
  deployment_stage:
    default: "dev"

# databricks/targets.yml
targets:
  dev:
    variables:
      deployment_stage: "dev"  # Redundant!
  
  staging:
    variables:
      deployment_stage: "staging"  # Redundant!

# databricks/resources/dbxload_job.yml
name: "${var.deployment_stage}-job"
```

**Problems**:
- Redundant: We're defining something that already exists
- Error-prone: Could mismatch target name and variable value
- Extra configuration: More lines to maintain

### ✅ After (Built-in Variable)
```yaml
# databricks/variables.yml
# No deployment_stage variable needed!

# databricks/targets.yml
targets:
  dev:
    # No deployment_stage override needed!
  
  staging:
    # No deployment_stage override needed!

# databricks/resources/dbxload_job.yml
name: "${bundle.target}-job"
```

**Benefits**:
- DRY (Don't Repeat Yourself): Target name used directly
- Less code: Fewer lines to maintain
- Type-safe: Always matches the actual target name
- Best practice: Using platform features correctly

---

## Practical Examples

### Example 1: Environment-Specific Resource Naming
```yaml
resources:
  jobs:
    worker:
      name: "${bundle.target}-${bundle.name}"
      # dev → dev-ct-lakehouse-dbxload
      # prod → prod-ct-lakehouse-dbxload
```

### Example 2: Version Management
```yaml
targets:
  dev:
    variables:
      artifact_version: "${bundle.git.commit_timestamp}"
      # Uses commit timestamp: 1699564800
  
  prod:
    variables:
      artifact_version: "${bundle.git.tag}"
      # Uses git tag: v1.0.0
```

### Example 3: Comprehensive Tagging
```yaml
resources:
  jobs:
    my_job:
      tags:
        environment: "${bundle.target}"
        bundle: "${bundle.name}"
        git_branch: "${bundle.git.branch}"
        git_commit: "${bundle.git.commit}"
        version: "${bundle.git.tag}"
        deployed_at: "${bundle.git.commit_timestamp}"
```

### Example 4: Job Parameters
```yaml
resources:
  jobs:
    my_job:
      parameters:
        - name: environment
          default: "${bundle.target}"
        
        - name: version
          default: "${bundle.git.commit_timestamp}"

# When job runs, it receives:
# environment=dev (or staging, or prod)
# version=1699564800
```

---

## Combining Built-in and Custom Variables

You can use both together:

```yaml
# Built-in for environment name
job_name: "${bundle.target}-worker"

# Custom for configuration values
max_workers: ${var.max_workers}
cluster_size: ${var.node_type}

# Built-in for versioning
artifact_version: "${bundle.git.commit_timestamp}"

# Result:
# name: dev-worker
# max_workers: 8 (from variables.yml)
# cluster_size: Standard_D4ds_v5 (from variables.yml)
# artifact_version: 1699564800 (from git)
```

---

## Common Patterns

### Pattern 1: Development vs Production Versioning
```yaml
targets:
  dev:
    variables:
      # Use commit timestamp for rapid iteration
      jar_version: "${bundle.git.commit_timestamp}"
  
  prod:
    variables:
      # Use tags for stable releases
      jar_version: "${bundle.git.tag}"
```

### Pattern 2: Resource Naming Convention
```yaml
# Format: {environment}-{project}-{resource}
resources:
  jobs:
    worker:
      name: "${bundle.target}-lakehouse-worker"
    
  clusters:
    analytics:
      cluster_name: "${bundle.target}-lakehouse-analytics"
```

### Pattern 3: Audit Trail
```yaml
resources:
  jobs:
    my_job:
      tags:
        managed_by: "databricks-asset-bundles"
        bundle_name: "${bundle.name}"
        environment: "${bundle.target}"
        git_commit: "${bundle.git.commit}"
        deployed_by: "github-actions"
```

---

## Troubleshooting

### "Variable bundle.target not found"

**Problem**: Trying to use `${var.bundle.target}` instead of `${bundle.target}`

**Solution**: Built-in variables don't use the `var.` prefix:
```yaml
# ❌ Wrong
name: "${var.bundle.target}-job"

# ✅ Correct
name: "${bundle.target}-job"
```

### "Git variables are empty"

**Problem**: `${bundle.git.tag}` or `${bundle.git.branch}` returns empty string

**Solution**: Ensure you're deploying from a git repository:
```bash
# Check git status
git status

# For tags, ensure you have tags
git tag -l

# For production, create and push a tag
git tag v1.0.0
git push origin v1.0.0
```

### "Timestamp not updating"

**Problem**: `${bundle.git.commit_timestamp}` shows old timestamp

**Solution**: Make a new commit:
```bash
git commit --allow-empty -m "Trigger new deployment"
git push
```

---

## References

- [Databricks Asset Bundle Variables](https://docs.databricks.com/dev-tools/bundles/settings.html#variables)
- [Bundle Configuration Reference](https://docs.databricks.com/dev-tools/bundles/settings.html)
- [Git Integration](https://docs.databricks.com/dev-tools/bundles/settings.html#git-metadata)

---

## Quick Reference

| Variable | Purpose | Example Value |
|----------|---------|---------------|
| `${bundle.target}` | Current environment | `dev`, `staging`, `prod` |
| `${bundle.name}` | Bundle name | `ct-lakehouse-dbxload` |
| `${bundle.git.branch}` | Git branch | `main`, `develop` |
| `${bundle.git.commit}` | Git commit SHA | `a1b2c3d4...` |
| `${bundle.git.commit_timestamp}` | Commit timestamp | `1699564800` |
| `${bundle.git.tag}` | Git tag | `v1.0.0` |
| `${workspace.host}` | Workspace URL | `https://adb-xxx.net` |

**Pro Tip**: Use `${bundle.target}` wherever you need the environment name - it's the most commonly used built-in variable!


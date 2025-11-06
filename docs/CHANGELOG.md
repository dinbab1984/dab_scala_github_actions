# Changelog

## Changes Summary

### Latest Changes: Simplified Workflow (Dev-Only)

**Date**: 2025-11-05

#### What Changed

Simplified the GitHub Actions workflow to focus only on **dev environment** deployment.

#### Files Modified

1. **.github/workflows/databricks-deploy.yml**
   - ❌ Removed `deploy-staging` job
   - ❌ Removed `deploy-prod` job
   - ❌ Removed `test-deployment` job (functionality moved to deploy-dev)
   - ✅ Simplified validation to dev-only
   - ✅ Updated workflow name to "Deploy to Dev"
   - ✅ Simplified triggers (push to develop/feature, PR to main, manual)

2. **.github/workflows/SIMPLIFIED.md**
   - ✅ Created documentation for simplified workflow
   - ✅ Documented what was removed and why
   - ✅ Added testing and restoration guide

#### Impact

**Reduction**:
- Lines: 446 → 245 (45% reduction)
- Jobs: 6 → 3 (50% reduction)
- Environments: 3 → 1 (dev only)

**Benefits**:
- ✅ Easier to understand and maintain
- ✅ Faster execution (no staging/prod overhead)
- ✅ Less configuration (fewer secrets needed)
- ✅ Focused on dev environment testing

**Staging/Prod Deployment**:
- Can be done manually with Databricks CLI
- Can create separate workflows later if needed
- Configuration still exists in `databricks/targets.yml`

---

### Previous Changes: Enhanced CI/CD Workflow for PR Testing

**Date**: 2025-11-05

#### What Changed

Updated GitHub Actions workflow to automatically test PRs on `main` branch by running the full job in dev environment.

#### Files Modified

1. **.github/workflows/databricks-deploy.yml**
   - ✅ Added SBT test step before building JAR
   - ✅ Updated `deploy-dev` trigger to include PRs on `main`
   - ✅ Added job execution for PRs (30-minute timeout)
   - ✅ Enhanced PR comments with test results
   - ✅ Updated job finding logic to use `${bundle.target}` naming
   - ✅ Separated PR testing from branch smoke tests

2. **.github/workflows/README.md**
   - ✅ Created comprehensive workflow documentation
   - ✅ Documented all trigger events and jobs
   - ✅ Added usage examples and troubleshooting

3. **databricks/CHEATSHEET.md**
   - ✅ Added GitHub Actions workflow section
   - ✅ Documented PR testing behavior

#### New Behavior

**When PR is created targeting `main` branch**:
```
1. Run SBT unit tests
   ↓
2. Build JAR artifact
   ↓
3. Validate bundle configuration
   ↓
4. Deploy to dev environment
   ↓
5. Upload JAR to dev volume
   ↓
6. Run job in dev (wait up to 30 minutes)
   ↓
7. Post results as PR comment
```

**PR Comment Example**:
```markdown
✅ Dev Environment - Deployment and Test succeeded

**Deployment:**
- Version: `20231109-143022-a1b2c3d`
- Job: [dev-dbxload-worker](link)

**Test Run:**
- Run ID: [`987654`](link)
- Status: `TERMINATED`
- Result: `SUCCESS`

✅ All tests passed! Ready for review.
```

#### Benefits

1. ✅ **Early Bug Detection**: Catch issues before merging to main
2. ✅ **Full Integration Testing**: Tests actual job execution, not just unit tests
3. ✅ **Automated Feedback**: PR comments show pass/fail status
4. ✅ **Better Code Quality**: Forces testing before merge
5. ✅ **Clear Visibility**: Reviewers see test results in PR
6. ✅ **Faster Iteration**: Developers get immediate feedback

#### Impact

- ✅ PRs to `main` now take longer (includes job execution time)
- ✅ More thorough validation before merging
- ✅ Prevents broken code from reaching staging/production
- ✅ No breaking changes to existing workflows

---

### Previous Changes: Using Built-in `${bundle.target}` Variable

**Date**: 2025-11-05

#### What Changed

Replaced custom `deployment_stage` variable with Databricks built-in `${bundle.target}` variable throughout the configuration.

#### Files Modified

1. **databricks/variables.yml**
   - ❌ Removed `deployment_stage` variable definition
   - ✅ Added comment explaining `${bundle.target}` is available as built-in

2. **databricks/targets.yml**
   - ❌ Removed `deployment_stage` overrides from all targets (dev, staging, prod)
   - ✅ Cleaner configuration with less redundancy

3. **databricks/resources/dbxload_job.yml**
   - ❌ Replaced all `${var.deployment_stage}` references
   - ✅ Now using `${bundle.target}` in 7 locations:
     - Job name: `${bundle.target}-dbxload-worker`
     - Job parameter default: `stage: ${bundle.target}`
     - Job cluster key: `${bundle.target}-dbxload` (4 instances)
     - Environment tag: `environment: ${bundle.target}`

#### Why This Change?

**Before** (Custom Variable):
```yaml
# Had to define and override in every environment
variables:
  deployment_stage:
    default: "dev"

targets:
  dev:
    variables:
      deployment_stage: "dev"  # Redundant!
```

**After** (Built-in Variable):
```yaml
# No definition needed - automatically available
# Uses: ${bundle.target}
# Values: dev, staging, prod (based on deployment target)
```

**Benefits**:
1. ✅ **DRY Principle**: Don't repeat yourself - target name used directly
2. ✅ **Less Code**: Removed ~6 lines of redundant configuration
3. ✅ **Type-Safe**: Always matches actual target name
4. ✅ **Best Practice**: Using Databricks platform features correctly
5. ✅ **Maintainable**: Fewer places where bugs can occur

#### Impact

- ✅ No breaking changes - deployments work the same way
- ✅ Job names remain the same: `dev-dbxload-worker`, `staging-dbxload-worker`, `prod-dbxload-worker`
- ✅ Cluster names remain the same: `dev-dbxload`, `staging-dbxload`, `prod-dbxload`
- ✅ Job parameters receive the same values

#### Documentation Added

Created **BUILTIN_VARIABLES.md** documenting:
- All Databricks built-in variables
- When to use built-in vs custom variables
- Practical examples and patterns
- Troubleshooting guide

---

## Previous Changes: Service Principal Separation

**Date**: 2025-11-05

#### What Changed

Split service principal configuration into two separate identities:

1. **deployment_sp**: Used for deploying the bundle
   - Creates/updates jobs
   - Modifies cluster configurations
   - Uploads artifacts

2. **run_as_sp**: Used for job execution
   - Runs jobs
   - Accesses Unity Catalog
   - Accesses Azure Storage

#### Files Modified

1. **databricks/variables.yml**
   - Added `deployment_sp` variable
   - Added `run_as_sp` variable

2. **databricks/targets.yml**
   - Each target now defines both service principals
   - `run_as` at target level uses `deployment_sp`

3. **databricks/resources/dbxload_job.yml**
   - Job `run_as` uses `run_as_sp`

#### Benefits

- ✅ **Security**: Principle of least privilege
- ✅ **Audit**: Separate identities for different operations
- ✅ **Compliance**: Meets security requirements
- ✅ **Best Practice**: Industry standard approach

#### Documentation Added

Created **SERVICE_PRINCIPALS.md** with:
- Setup instructions
- Permission requirements
- Troubleshooting guide

---

## Initial Implementation: Databricks Asset Bundle

**Date**: 2025-11-05

### Features Implemented

#### 1. Modular Configuration
- Split configuration into separate files:
  - `databricks.yml` - Main entry point
  - `databricks/variables.yml` - All variables
  - `databricks/targets.yml` - Environments
  - `databricks/resources/dbxload_job.yml` - Job definition

#### 2. Multi-Environment Support
- Development (dev)
- Staging (staging)
- Production (prod)
- Each with specific configurations

#### 3. CI/CD Pipeline
- GitHub Actions workflow
- Automated build, validate, deploy
- Environment-specific deployments
- OIDC authentication

#### 4. Helper Tools
- `deploy.sh` - Interactive deployment script
- `.databrickscfg.template` - CLI configuration template
- `.env.template` - Environment variables template

#### 5. Comprehensive Documentation
- README.md - Main documentation
- QUICKSTART.md - 5-minute guide
- STRUCTURE.md - Configuration structure
- SERVICE_PRINCIPALS.md - Security setup
- ARCHITECTURE.md - System architecture
- SUMMARY.md - Implementation overview
- CHEATSHEET.md - Command reference
- BUILTIN_VARIABLES.md - Built-in variables

### Key Features

- ✅ Infrastructure as Code
- ✅ Version control for all configuration
- ✅ Automated validation before deployment
- ✅ Environment-specific scaling
- ✅ Git-based versioning
- ✅ SPOT instances for cost optimization
- ✅ Security best practices

---

## Migration Notes

### From JSON to DAB

**Before**: Manual JSON with placeholders
```json
{
  "tasks": [{
    "jar": "/Volumes/XXXWORKSPACEXXX/..."
  }]
}
```

**After**: Parameterized YAML
```yaml
resources:
  jobs:
    dbxload_worker:
      libraries:
        - jar: "/Volumes/${var.catalog_name}/${var.schema_name}/${var.volume_name}/jars/..."
```

### Benefits of Migration

1. **No Manual Placeholders**: Variables automatically substituted
2. **Version Controlled**: All changes tracked in git
3. **Validated**: Configuration validated before deployment
4. **Reusable**: Single config works for all environments
5. **Automated**: CI/CD pipeline handles deployment

---

## Future Enhancements

Planned improvements:
- [ ] Add integration tests
- [ ] Implement canary deployments
- [ ] Add monitoring dashboards
- [ ] Automated rollback on failure
- [ ] Additional environments (qa, uat)
- [ ] Azure DevOps integration
- [ ] Terraform for Azure resources
- [ ] Secret rotation automation

---

## Version History

| Version | Date | Description |
|---------|------|-------------|
| 1.4.0 | 2025-11-05 | Simplified workflow to dev-only deployment |
| 1.3.0 | 2025-11-05 | Enhanced CI/CD with PR testing and job execution |
| 1.2.0 | 2025-11-05 | Use built-in ${bundle.target} variable |
| 1.1.0 | 2025-11-05 | Split service principals (deployment_sp, run_as_sp) |
| 1.0.0 | 2025-11-05 | Initial Databricks Asset Bundle implementation |

---

## Breaking Changes

None so far. All changes have been backward compatible.

---

## Deprecations

- `deployment_stage` variable (replaced by `${bundle.target}` built-in)
  - Deprecated in: v1.2.0
  - Reason: Redundant with built-in functionality
  - Migration: Replace `${var.deployment_stage}` with `${bundle.target}`

---

## Contributors

- Data Platform Team
- ContiTech DNA

---

## Support

For questions or issues:
- Create GitHub issue
- Contact: data-platform-team@contitech.com
- Documentation: See README.md


# GitHub Actions Workflow Documentation

## Overview

This document explains the CI/CD pipeline for deploying Databricks jobs using Databricks Asset Bundles.

## Workflow File

- **File**: `.github/workflows/databricks-deploy.yml`
- **Name**: Deploy to Databricks

## Trigger Events

### 1. Pull Request on `main` or `develop`
```yaml
pull_request:
  branches:
    - main
    - develop
```
**Behavior**:
- Runs all tests (SBT unit tests)
- Builds JAR artifact
- Validates bundle configuration
- **For PRs on `main`**: Deploys to dev, uploads JAR to volume, and runs the job
- Posts results as PR comment

### 2. Push to Branches
```yaml
push:
  branches:
    - main
    - develop
    - 'feature/**'
```
**Behavior**:
- **`main` branch**: Deploys to staging environment
- **`develop` branch**: Deploys to dev environment
- **`feature/*` branches**: Deploys to dev environment

### 3. Manual Workflow Dispatch
```yaml
workflow_dispatch:
  inputs:
    environment: [dev, staging, prod]
```
**Behavior**:
- Manual trigger from GitHub Actions UI
- Allows deployment to any environment
- Used for production deployments

## Jobs

### 1. `build` - Build Artifacts

**Triggers**: Always runs on all events

**Steps**:
1. ✅ Checkout code
2. ✅ Setup JDK 11 with SBT cache
3. ✅ Configure SBT credentials
4. ✅ **Run unit tests** (`sbt test`)
5. ✅ Build JAR (`sbt clean compile package`)
6. ✅ Version artifact with timestamp and git commit
7. ✅ Upload artifact for subsequent jobs

**Output**:
- JAR artifact: `lakehouse-dbx-job-{timestamp}-{commit}.jar`
- Stored in GitHub Actions artifacts (30-day retention)

---

### 2. `validate` - Validate Bundle Configuration

**Triggers**: After `build` completes

**Strategy**: Matrix job for all environments (dev, staging, prod)

**Steps**:
1. ✅ Checkout code
2. ✅ Setup Databricks CLI
3. ✅ Validate bundle for each environment

**Purpose**: Catch configuration errors early

---

### 3. `deploy-dev` - Deploy to Development

**Triggers**:
- ✅ Pull requests targeting `main` branch
- ✅ Push to `develop` branch
- ✅ Push to `feature/*` branches

**Steps**:
1. ✅ Checkout code and download artifacts
2. ✅ Setup Databricks CLI
3. ✅ Authenticate with Azure (OIDC)
4. ✅ Upload JAR to Databricks Volume
5. ✅ Deploy bundle to dev environment
6. ✅ **Get Job ID** (finds job by name pattern)
7. ✅ **Run Job** (only for PRs - waits for completion)
8. ✅ **Post PR Comment** with deployment and test results

**Environment**: `dev`

**For Pull Requests on main**:
```
┌─────────────────┐
│  Run Tests      │
└────────┬────────┘
         │
┌────────▼────────┐
│  Build JAR      │
└────────┬────────┘
         │
┌────────▼────────┐
│  Upload to      │
│  Volume         │
└────────┬────────┘
         │
┌────────▼────────┐
│  Deploy Bundle  │
└────────┬────────┘
         │
┌────────▼────────┐
│  Run Job in Dev │
│  (Wait 30min)   │
└────────┬────────┘
         │
┌────────▼────────┐
│  Post PR        │
│  Comment        │
└─────────────────┘
```

**PR Comment Example**:
```markdown
✅ Dev Environment - Deployment and Test succeeded

**Deployment:**
- Version: `20231109-143022-a1b2c3d`
- Job: [dev-dbxload-worker](https://adb-xxx.net/#job/12345)

**Test Run:**
- Run ID: [`987654`](https://adb-xxx.net/#job/12345/run/987654)
- Status: `TERMINATED`
- Result: `SUCCESS`

✅ All tests passed! Ready for review.
```

---

### 4. `deploy-staging` - Deploy to Staging

**Triggers**: Push to `main` branch

**Steps**:
1. ✅ Download artifacts
2. ✅ Setup Databricks CLI
3. ✅ Authenticate with Azure
4. ✅ Upload JAR to staging volume
5. ✅ Deploy bundle to staging

**Environment**: `staging`

**Note**: Does NOT automatically run the job (manual verification recommended)

---

### 5. `deploy-prod` - Deploy to Production

**Triggers**: Manual workflow dispatch when on `main` branch

**Steps**:
1. ✅ Download artifacts
2. ✅ Setup Databricks CLI
3. ✅ Authenticate with Azure
4. ✅ Upload JAR to production volume
5. ✅ Deploy bundle to prod
6. ✅ Create GitHub release

**Environment**: `prod`

**Requirements**:
- Must be on `main` branch
- Must be triggered manually
- Requires approval (configured in GitHub environment settings)

---

### 6. `test-deployment` - Smoke Tests

**Triggers**: After `deploy-dev` for `develop` or `feature/*` branches (NOT PRs)

**Steps**:
1. ✅ Find job by name pattern
2. ✅ Trigger job run
3. ✅ Wait for completion (30-minute timeout)
4. ✅ Verify success (fails if job fails)

**Purpose**: Automated smoke testing for direct branch pushes

---

## Environment Variables

```yaml
env:
  DATABRICKS_CLI_VERSION: '0.213.0'
  JAVA_VERSION: '11'
  SBT_VERSION: '1.9.7'
```

## Required GitHub Secrets

### Per Environment (dev, staging, prod)

| Secret | Purpose | Example |
|--------|---------|---------|
| `DATABRICKS_HOST_{ENV}` | Workspace URL | `https://adb-xxx.azuredatabricks.net` |
| `DATABRICKS_TOKEN_{ENV}` | Access token | `dapi_xxxxx` |
| `AZURE_CLIENT_ID_{ENV}` | Deployment SP client ID | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| `AZURE_SUBSCRIPTION_ID_{ENV}` | Azure subscription | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |

### Global

| Secret | Purpose |
|--------|---------|
| `AZURE_TENANT_ID` | Azure AD tenant ID |
| `ARTIFACTORY_USERNAME` | SBT dependency resolution |
| `ARTIFACTORY_PASSWORD` | SBT dependency resolution |

## Workflow Decision Tree

```
Event Received
│
├─ PR on main?
│  ├─ Yes → Build + Test + Deploy to Dev + Run Job + Comment on PR
│  └─ No → Continue
│
├─ PR on develop?
│  ├─ Yes → Build + Test + Deploy to Dev + Comment on PR (no job run)
│  └─ No → Continue
│
├─ Push to main?
│  ├─ Yes → Build + Test + Deploy to Staging
│  └─ No → Continue
│
├─ Push to develop?
│  ├─ Yes → Build + Test + Deploy to Dev + Smoke Test (run job)
│  └─ No → Continue
│
├─ Push to feature/*?
│  ├─ Yes → Build + Test + Deploy to Dev + Smoke Test (run job)
│  └─ No → Continue
│
└─ Manual dispatch?
   └─ Yes → Build + Test + Deploy to {selected environment}
```

## Key Features

### 1. **Test-First Approach**
- ✅ Unit tests run before building
- ✅ Integration tests run in dev environment
- ✅ Build fails if tests fail

### 2. **PR Validation**
- ✅ Full deployment to dev on PR to main
- ✅ Actual job execution with 30-minute timeout
- ✅ Automated PR comments with results
- ✅ Prevents merging broken code

### 3. **Environment Promotion**
- ✅ Dev → Staging → Prod
- ✅ Staging deploys automatically from main
- ✅ Prod requires manual approval

### 4. **Artifact Versioning**
- ✅ Timestamp-based for dev/staging
- ✅ Git tag-based for prod
- ✅ Full traceability to source code

### 5. **Security**
- ✅ OIDC authentication (no long-lived secrets)
- ✅ Separate service principals per environment
- ✅ GitHub environment protection rules

### 6. **Observability**
- ✅ PR comments with clickable links
- ✅ Job status and results
- ✅ Direct links to Databricks UI

## Usage Examples

### Example 1: Feature Development

```bash
# Create feature branch
git checkout -b feature/new-feature

# Make changes and push
git add .
git commit -m "Add new feature"
git push origin feature/new-feature

# Workflow automatically:
# 1. Runs tests
# 2. Builds JAR
# 3. Deploys to dev
# 4. Runs smoke test
```

### Example 2: Pull Request to Main

```bash
# Create PR from feature branch to main
gh pr create --base main --head feature/new-feature

# Workflow automatically:
# 1. Runs all unit tests
# 2. Builds JAR
# 3. Deploys to dev
# 4. Runs full job test
# 5. Posts results on PR

# Review PR comment for test results
# Merge when tests pass
```

### Example 3: Deploy to Production

```bash
# After merge to main, staging is automatically deployed

# For production:
# 1. Go to GitHub Actions
# 2. Select "Deploy to Databricks" workflow
# 3. Click "Run workflow"
# 4. Select "prod" environment
# 5. Click "Run workflow"
# 6. Approve deployment (if protection rules are set)
```

## Debugging

### Job Not Found Error

**Symptom**: `Job not found!` in workflow logs

**Solution**: Verify job name pattern
```bash
# Job should be named: {bundle.target}-dbxload-worker
# Examples: dev-dbxload-worker, staging-dbxload-worker
```

### Timeout Errors

**Symptom**: Job times out after 30 minutes

**Options**:
1. Increase timeout in workflow
2. Make job run faster
3. Run job asynchronously (remove wait)

```yaml
# To run async (don't wait):
databricks runs wait --run-id $RUN_ID --timeout 30m || true
```

### Authentication Failures

**Symptom**: `Authentication failed` or `Token expired`

**Solution**:
1. Verify secrets are set correctly
2. Check token expiration
3. Verify OIDC configuration

```bash
# Test authentication locally
export DATABRICKS_HOST="..."
export DATABRICKS_TOKEN="..."
databricks auth describe
```

## Best Practices

### 1. Test Locally First
```bash
# Before pushing, test locally
sbt "project lakehouseDBXJob" test
databricks bundle validate -t dev
```

### 2. Use Descriptive Commit Messages
```bash
git commit -m "feat: Add new load strategy
- Implement OPTIMISTIC load strategy
- Add tests for edge cases
- Update documentation"
```

### 3. Monitor PR Comments
- Check test results in PR comments
- Click through to Databricks for detailed logs
- Don't merge if tests fail

### 4. Use Draft PRs for WIP
```bash
# Create draft PR for work in progress
gh pr create --draft --base main
```

### 5. Tag Production Releases
```bash
# After successful prod deployment
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0
```

## Customization

### Change Test Timeout

```yaml
# In deploy-dev job, modify:
databricks runs wait --run-id $RUN_ID --timeout 60m  # Change from 30m to 60m
```

### Add Test Coverage Reporting

```yaml
- name: Generate coverage report
  run: |
    sbt "project lakehouseDBXJob" coverage test coverageReport
    
- name: Upload coverage to Codecov
  uses: codecov/codecov-action@v3
```

### Add Slack Notifications

```yaml
- name: Notify Slack
  if: failure()
  uses: slackapi/slack-github-action@v1
  with:
    webhook-url: ${{ secrets.SLACK_WEBHOOK }}
    payload: |
      {
        "text": "Deployment failed: ${{ github.ref }}"
      }
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Tests fail | Check SBT test output, fix failing tests |
| Build fails | Verify SBT credentials, check compilation errors |
| Validation fails | Run `databricks bundle validate` locally |
| Deployment fails | Check Databricks permissions, verify secrets |
| Job not found | Verify job naming convention (`dev-dbxload-worker`) |
| Job fails | Check Databricks job logs, verify configuration |

## Support

- **Documentation**: [README.md](../../databricks/README.md)
- **Issues**: Create GitHub issue
- **Team**: data-platform-team@contitech.com


# Architecture Overview

This document provides a visual overview of the Databricks Asset Bundle architecture and deployment flow.

## System Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              GitHub Repository                               │
│                                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │
│  │ Scala Source │  │ Build Config │  │ DAB Config   │  │ CI/CD        │   │
│  │ Code (SBT)   │  │ (build.sbt)  │  │ (YAML files) │  │ (GitHub      │   │
│  │              │  │              │  │              │  │  Actions)     │   │
│  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ git push
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                            GitHub Actions (CI/CD)                            │
│                                                                              │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐             │
│  │  Build   │───▶│ Validate │───▶│  Deploy  │───▶│   Test   │             │
│  │  JAR     │    │  Bundle  │    │  Bundle  │    │  Smoke   │             │
│  └──────────┘    └──────────┘    └──────────┘    └──────────┘             │
│       │                │                │                                    │
│       │                │                │ Uses Deployment SP                 │
│       │                │                └────────────────┐                   │
└───────┼────────────────┼─────────────────────────────────┼──────────────────┘
        │                │                                  │
        │ Upload JAR     │ Validate Config                 │ Deploy Resources
        ▼                ▼                                  ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         Databricks Workspace                                 │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────┐       │
│  │                        Unity Catalog                             │       │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │       │
│  │  │   Catalog    │  │    Schema    │  │    Volume    │          │       │
│  │  │  (dev/prod)  │  │ (deployments)│  │  (pipeline)  │          │       │
│  │  └──────────────┘  └──────────────┘  └──────┬───────┘          │       │
│  │                                              │ JAR Storage       │       │
│  │                                              │                   │       │
│  └──────────────────────────────────────────────┼───────────────────┘       │
│                                                  │                           │
│  ┌──────────────────────────────────────────────┼───────────────────┐       │
│  │                       Job Definition         │                   │       │
│  │                                              ▼                   │       │
│  │  ┌────────────────────────────────────────────────────┐         │       │
│  │  │              DBXLoad Worker Job                    │         │       │
│  │  │  (Runs as: Runtime SP)                            │         │       │
│  │  │                                                    │         │       │
│  │  │  ┌──────────────┐                                 │         │       │
│  │  │  │  JobSetup    │  (Task 1)                       │         │       │
│  │  │  └──────┬───────┘                                 │         │       │
│  │  │         │                                          │         │       │
│  │  │         ├────────────┬─────────────────┐          │         │       │
│  │  │         ▼            ▼                 ▼          │         │       │
│  │  │  ┌────────────┐  ┌──────────────────────────┐    │         │       │
│  │  │  │LoadItem    │  │LoadItemExecutor_Loop     │    │         │       │
│  │  │  │Producer    │  │(For-Each with 8 workers) │    │         │       │
│  │  │  └────────────┘  └──────────────────────────┘    │         │       │
│  │  │                                                    │         │       │
│  │  └────────────────────────────────────────────────────┘         │       │
│  │                                                                  │       │
│  └──────────────────────────────────────────────────────────────────┘       │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────┐       │
│  │                      Job Clusters                                │       │
│  │                                                                  │       │
│  │  ┌────────────────────────────────────────────────────────┐     │       │
│  │  │  Driver (Standard_D4ds_v5)                             │     │       │
│  │  │  Workers (1-8) with Autoscaling                        │     │       │
│  │  │  SPOT instances with fallback                          │     │       │
│  │  └────────────────────────────────────────────────────────┘     │       │
│  │                                                                  │       │
│  └──────────────────────────────────────────────────────────────────┘       │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ Job Runtime Access
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                            Azure Resources                                   │
│                                                                              │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐         │
│  │ Storage Account  │  │  Azure Queues    │  │  Azure Tables    │         │
│  │                  │  │                  │  │                  │         │
│  │  - Blob Storage  │  │  - worker-       │  │  - meta table    │         │
│  │  - Data Lake     │  │    monitoring    │  │                  │         │
│  │                  │  │  - worker-       │  │                  │         │
│  │                  │  │    dbxload       │  │                  │         │
│  └──────────────────┘  └──────────────────┘  └──────────────────┘         │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Configuration Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      Configuration Hierarchy                                 │
│                                                                              │
│  1. databricks.yml (Main Entry Point)                                       │
│     │                                                                        │
│     ├─▶ 2. databricks/variables.yml (Variable Definitions)                 │
│     │      │                                                                 │
│     │      ├─ workspace_name                                                │
│     │      ├─ deployment_sp                                                 │
│     │      ├─ run_as_sp                                                     │
│     │      ├─ catalog_name                                                  │
│     │      ├─ storage_account_name                                          │
│     │      ├─ spark_version                                                 │
│     │      ├─ max_workers                                                   │
│     │      └─ ... (130+ variables)                                          │
│     │                                                                        │
│     ├─▶ 3. databricks/targets.yml (Environment Overrides)                  │
│     │      │                                                                 │
│     │      ├─ dev:                                                          │
│     │      │    workspace: adb-dev                                          │
│     │      │    variables: { max_workers: 8 }                               │
│     │      │                                                                 │
│     │      ├─ staging:                                                      │
│     │      │    workspace: adb-staging                                      │
│     │      │    variables: { max_workers: 12 }                              │
│     │      │                                                                 │
│     │      └─ prod:                                                         │
│     │           workspace: adb-prod                                         │
│     │           variables: { max_workers: 16 }                              │
│     │                                                                        │
│     └─▶ 4. databricks/resources/dbxload_job.yml (Job Definition)           │
│            │                                                                 │
│            └─ Uses variables: ${var.workspace_name}                         │
│                               ${var.run_as_sp}                              │
│                               ${var.catalog_name}                           │
│                               etc...                                        │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Service Principal Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      Service Principal Separation                            │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────┐       │
│  │                    Deployment Service Principal                  │       │
│  │                         (deployment_sp)                          │       │
│  │                                                                  │       │
│  │  Used By: GitHub Actions, Local Deployment                      │       │
│  │                                                                  │       │
│  │  Permissions:                                                    │       │
│  │  ✓ CREATE/UPDATE/DELETE jobs                                    │       │
│  │  ✓ MODIFY cluster configurations                                │       │
│  │  ✓ UPLOAD artifacts to volumes                                  │       │
│  │  ✓ VALIDATE bundle configuration                                │       │
│  │  ✗ RUN jobs (not needed)                                        │       │
│  │  ✗ ACCESS Azure Storage (not needed)                            │       │
│  │  ✗ ACCESS data (not needed)                                     │       │
│  │                                                                  │       │
│  └──────────────────────────────────────────────────────────────────┘       │
│                                │                                             │
│                                │ Deploys Job Configuration                   │
│                                ▼                                             │
│  ┌──────────────────────────────────────────────────────────────────┐       │
│  │                       Runtime Service Principal                  │       │
│  │                            (run_as_sp)                           │       │
│  │                                                                  │       │
│  │  Used By: Databricks Job Execution                              │       │
│  │                                                                  │       │
│  │  Permissions:                                                    │       │
│  │  ✗ CREATE/UPDATE jobs (not needed)                              │       │
│  │  ✓ RUN jobs                                                      │       │
│  │  ✓ ACCESS Unity Catalog (read/write)                            │       │
│  │  ✓ ACCESS Azure Storage (queues, blobs, tables)                 │       │
│  │  ✓ ACCESS Azure Key Vault (secrets)                             │       │
│  │  ✓ READ/WRITE volumes                                           │       │
│  │                                                                  │       │
│  └──────────────────────────────────────────────────────────────────┘       │
│                                                                              │
│  Why Separate?                                                               │
│  • Principle of Least Privilege                                             │
│  • Better Audit Trail                                                        │
│  • Reduced Security Risk                                                     │
│  • Compliance Requirements                                                   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Deployment Pipeline

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         Deployment Pipeline Flow                             │
│                                                                              │
│  1. CODE CHANGE                                                              │
│     │                                                                        │
│     │ Developer pushes code to GitHub                                        │
│     ▼                                                                        │
│  ┌─────────────────────────────────────────────────┐                        │
│  │  GitHub Actions Trigger                         │                        │
│  │  - Push to develop → deploy to dev              │                        │
│  │  - Push to main → deploy to staging             │                        │
│  │  - Manual trigger → deploy to prod              │                        │
│  └─────────────────────────────────────────────────┘                        │
│     │                                                                        │
│     ▼                                                                        │
│  2. BUILD PHASE                                                              │
│     │                                                                        │
│     ├─▶ Setup JDK & SBT                                                     │
│     ├─▶ Compile Scala code                                                  │
│     ├─▶ Run unit tests                                                      │
│     ├─▶ Package JAR                                                         │
│     └─▶ Create artifact (lakehouse-dbx-job-{version}.jar)                  │
│         │                                                                    │
│         ▼                                                                    │
│  3. VALIDATE PHASE                                                           │
│     │                                                                        │
│     ├─▶ Validate bundle syntax                                              │
│     ├─▶ Check variable references                                           │
│     ├─▶ Verify resource definitions                                         │
│     └─▶ Validate for all environments (dev/staging/prod)                    │
│         │                                                                    │
│         ▼                                                                    │
│  4. DEPLOY PHASE                                                             │
│     │                                                                        │
│     ├─▶ Authenticate with Deployment SP                                     │
│     ├─▶ Upload JAR to Unity Catalog Volume                                  │
│     ├─▶ Deploy bundle (databricks bundle deploy)                            │
│     │   • Create/Update job definition                                      │
│     │   • Configure clusters                                                │
│     │   • Set permissions                                                   │
│     └─▶ Verify deployment                                                   │
│         │                                                                    │
│         ▼                                                                    │
│  5. TEST PHASE (Optional)                                                    │
│     │                                                                        │
│     ├─▶ Trigger job run                                                     │
│     ├─▶ Monitor execution                                                   │
│     ├─▶ Validate outputs                                                    │
│     └─▶ Report results                                                      │
│         │                                                                    │
│         ▼                                                                    │
│  6. NOTIFICATION                                                             │
│     │                                                                        │
│     ├─▶ Update PR with deployment status                                    │
│     ├─▶ Send email notifications                                            │
│     └─▶ Create GitHub release (for prod)                                    │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Job Execution Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          Job Execution Architecture                          │
│                                                                              │
│  Job Triggered (Manual or Scheduled)                                         │
│     │                                                                        │
│     ▼                                                                        │
│  ┌─────────────────────────────────────────────────┐                        │
│  │  Cluster Provisioning                           │                        │
│  │  - Start with min_workers (1)                   │                        │
│  │  - Use SPOT instances with fallback             │                        │
│  │  - Apply cluster policy                         │                        │
│  └─────────────────────────────────────────────────┘                        │
│     │                                                                        │
│     ▼                                                                        │
│  ┌─────────────────────────────────────────────────┐                        │
│  │  Task 1: JobSetup                               │                        │
│  │  - Initialize configuration                     │                        │
│  │  - Validate credentials                         │                        │
│  │  - Setup monitoring                             │                        │
│  │  - Load SparkConfig                             │                        │
│  └─────────────────────────────────────────────────┘                        │
│     │                                                                        │
│     ├───────────────────────┬─────────────────────────────┐                 │
│     ▼                       ▼                             ▼                 │
│  ┌──────────────┐   ┌──────────────────────────────────────┐               │
│  │ Task 2:      │   │ Task 3: LoadItemExecutor_Loop        │               │
│  │ LoadItem     │   │                                      │               │
│  │ Producer     │   │  Parallel Execution (concurrency=4): │               │
│  │              │   │                                      │               │
│  │ - Read meta  │   │  ┌────────────┐  ┌────────────┐    │               │
│  │   table      │   │  │ Executor 1 │  │ Executor 2 │    │               │
│  │ - Produce    │   │  └────────────┘  └────────────┘    │               │
│  │   load items │   │  ┌────────────┐  ┌────────────┐    │               │
│  │ - Enqueue to │   │  │ Executor 3 │  │ Executor 4 │    │               │
│  │   dbxload    │   │  └────────────┘  └────────────┘    │               │
│  │   queue      │   │                                      │               │
│  │              │   │  Each executor:                      │               │
│  │              │   │  - Dequeue from Azure Queue          │               │
│  │              │   │  - Load data from source             │               │
│  │              │   │  - Transform data                    │               │
│  │              │   │  - Write to Unity Catalog            │               │
│  │              │   │  - Update monitoring queue           │               │
│  └──────────────┘   └──────────────────────────────────────┘               │
│     │                       │                                                │
│     │                       │                                                │
│     ▼                       ▼                                                │
│  ┌─────────────────────────────────────────────────┐                        │
│  │  Cluster Autoscaling                            │                        │
│  │  - Scales up to max_workers (8) on demand       │                        │
│  │  - Scales down when idle                        │                        │
│  └─────────────────────────────────────────────────┘                        │
│     │                                                                        │
│     ▼                                                                        │
│  ┌─────────────────────────────────────────────────┐                        │
│  │  Job Completion                                 │                        │
│  │  - Write final status                           │                        │
│  │  - Send notifications                           │                        │
│  │  - Terminate cluster                            │                        │
│  └─────────────────────────────────────────────────┘                        │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Environment Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        Environment Separation                                │
│                                                                              │
│  ┌───────────────────────────────────────────────────────────────┐          │
│  │  DEVELOPMENT (dev)                                            │          │
│  │  ┌──────────────────────────────────────────────────────┐    │          │
│  │  │ Workspace: adb-dev                                   │    │          │
│  │  │ Mode: development                                    │    │          │
│  │  │ Deployment SP: sp-dev-deployment                     │    │          │
│  │  │ Runtime SP: sp-dev-runtime                           │    │          │
│  │  │ Catalog: dev_catalog                                 │    │          │
│  │  │ Storage: ctdpdevdatastore                            │    │          │
│  │  │ Max Workers: 8                                       │    │          │
│  │  │ Versioning: git commit timestamp                     │    │          │
│  │  └──────────────────────────────────────────────────────┘    │          │
│  └───────────────────────────────────────────────────────────────┘          │
│                                                                              │
│  ┌───────────────────────────────────────────────────────────────┐          │
│  │  STAGING (staging)                                            │          │
│  │  ┌──────────────────────────────────────────────────────┐    │          │
│  │  │ Workspace: adb-staging                               │    │          │
│  │  │ Mode: production                                     │    │          │
│  │  │ Deployment SP: sp-staging-deployment                 │    │          │
│  │  │ Runtime SP: sp-staging-runtime                       │    │          │
│  │  │ Catalog: staging_catalog                             │    │          │
│  │  │ Storage: ctdpstagingdatastore                        │    │          │
│  │  │ Max Workers: 12                                      │    │          │
│  │  │ Versioning: git tag                                  │    │          │
│  │  │ Permissions: staging-users, staging-admins           │    │          │
│  │  └──────────────────────────────────────────────────────┘    │          │
│  └───────────────────────────────────────────────────────────────┘          │
│                                                                              │
│  ┌───────────────────────────────────────────────────────────────┐          │
│  │  PRODUCTION (prod)                                            │          │
│  │  ┌──────────────────────────────────────────────────────┐    │          │
│  │  │ Workspace: adb-prod                                  │    │          │
│  │  │ Mode: production                                     │    │          │
│  │  │ Deployment SP: sp-prod-deployment                    │    │          │
│  │  │ Runtime SP: sp-prod-runtime                          │    │          │
│  │  │ Catalog: prod_catalog                                │    │          │
│  │  │ Storage: ctdpproddatastore                           │    │          │
│  │  │ Max Workers: 16                                      │    │          │
│  │  │ Versioning: git tag                                  │    │          │
│  │  │ Permissions: prod-users, prod-admins, prod-operators │    │          │
│  │  │ Deployment: Manual approval required                 │    │          │
│  │  └──────────────────────────────────────────────────────┘    │          │
│  └───────────────────────────────────────────────────────────────┘          │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Key Design Principles

### 1. Separation of Concerns
- **Configuration** (variables.yml) ≠ **Environment** (targets.yml) ≠ **Resources** (dbxload_job.yml)
- Each file has a single responsibility

### 2. DRY (Don't Repeat Yourself)
- Variables defined once, used everywhere
- Environment-specific overrides only where needed
- Shared configuration across environments

### 3. Security by Default
- Separate deployment and runtime identities
- Least privilege access
- Secrets in Key Vault
- OIDC authentication

### 4. GitOps
- Everything in version control
- Automated deployments
- Code review process
- Audit trail

### 5. Scalability
- Environment-specific scaling
- Autoscaling clusters
- Parallel task execution
- SPOT instances for cost

## Technology Stack

```
┌─────────────────────────────────────────────────────────────┐
│  Language & Build                                           │
│  • Scala 2.13                                               │
│  • SBT (Simple Build Tool)                                  │
└─────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────┐
│  Data Platform                                              │
│  • Databricks (Spark 4.0.0)                                 │
│  • Unity Catalog                                            │
│  • Delta Lake                                               │
└─────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────┐
│  Infrastructure                                             │
│  • Databricks Asset Bundles (DAB)                           │
│  • Azure Storage (Blob, Queue, Table)                       │
│  • Azure Key Vault                                          │
└─────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────┐
│  CI/CD                                                      │
│  • GitHub Actions                                           │
│  • OIDC Authentication                                      │
│  • Multi-stage deployment                                   │
└─────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────┐
│  Security                                                   │
│  • Azure AD Service Principals                              │
│  • RBAC (Role-Based Access Control)                         │
│  • Unity Catalog permissions                                │
└─────────────────────────────────────────────────────────────┘
```

## References

- [Databricks Asset Bundles](https://docs.databricks.com/dev-tools/bundles/index.html)
- [Unity Catalog](https://docs.databricks.com/data-governance/unity-catalog/index.html)
- [GitHub Actions](https://docs.github.com/en/actions)
- [Azure RBAC](https://docs.microsoft.com/en-us/azure/role-based-access-control/overview)


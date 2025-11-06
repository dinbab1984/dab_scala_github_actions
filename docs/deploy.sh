#!/bin/bash

# Databricks Bundle Deployment Script
# This script helps deploy the bundle locally with proper error handling and validation

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored messages
info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to display usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Deploy Databricks Asset Bundle to specified environment.

OPTIONS:
    -e, --environment ENV    Environment to deploy to (dev|staging|prod). Default: dev
    -b, --build              Build JAR before deploying
    -v, --validate           Only validate, don't deploy
    -r, --run                Run the job after deployment
    -h, --help               Show this help message

EXAMPLES:
    # Deploy to dev environment
    $0 -e dev

    # Build and deploy to staging
    $0 -e staging -b

    # Validate production configuration
    $0 -e prod -v

    # Deploy and run the job
    $0 -e dev -r

EOF
}

# Default values
ENVIRONMENT="dev"
BUILD=false
VALIDATE_ONLY=false
RUN_JOB=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -b|--build)
            BUILD=true
            shift
            ;;
        -v|--validate)
            VALIDATE_ONLY=true
            shift
            ;;
        -r|--run)
            RUN_JOB=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            error "Unknown option: $1\nUse -h or --help for usage information."
            ;;
    esac
done

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    error "Invalid environment: $ENVIRONMENT. Must be dev, staging, or prod."
fi

# Check prerequisites
info "Checking prerequisites..."

if ! command_exists databricks; then
    error "Databricks CLI is not installed. Install it with: curl -fsSL https://raw.githubusercontent.com/databricks/setup-cli/main/install.sh | sh"
fi

if ! command_exists sbt; then
    warning "SBT is not installed. Building will fail if requested."
fi

success "Prerequisites check passed"

# Get project root directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

info "Project root: $PROJECT_ROOT"
info "Target environment: $ENVIRONMENT"

# Build JAR if requested
if [ "$BUILD" = true ]; then
    info "Building JAR artifact..."
    
    if ! sbt "project lakehouseDBXJob" clean package; then
        error "Failed to build JAR artifact"
    fi
    
    # Get JAR path
    JAR_FILE=$(find libs/_6_lakehouseDBXJob/target/scala-2.13 -name "lakehouse-dbx-job*.jar" -type f | head -n 1)
    
    if [ -z "$JAR_FILE" ]; then
        error "JAR file not found after build"
    fi
    
    success "JAR built successfully: $JAR_FILE"
else
    info "Skipping build (use -b to build)"
fi

# Validate bundle
info "Validating bundle configuration for $ENVIRONMENT..."

if ! databricks bundle validate -t "$ENVIRONMENT"; then
    error "Bundle validation failed for $ENVIRONMENT"
fi

success "Bundle validation passed"

# If validate only, exit here
if [ "$VALIDATE_ONLY" = true ]; then
    success "Validation complete. Exiting without deployment."
    exit 0
fi

# Get version for JAR
VERSION=$(date +%Y%m%d-%H%M%S)-$(git rev-parse --short HEAD 2>/dev/null || echo "local")
info "Artifact version: $VERSION"

# Upload JAR to Databricks Volume (if built)
if [ "$BUILD" = true ] && [ -n "$JAR_FILE" ]; then
    info "Uploading JAR to Databricks Volume..."
    
    # Determine volume path based on environment
    case $ENVIRONMENT in
        dev)
            CATALOG="dev_catalog"
            ;;
        staging)
            CATALOG="staging_catalog"
            ;;
        prod)
            CATALOG="prod_catalog"
            ;;
    esac
    
    VOLUME_PATH="dbfs:/Volumes/${CATALOG}/deployments/pipeline/jars/lakehouse-dbx-job-${VERSION}.jar"
    
    if ! databricks fs cp "$JAR_FILE" "$VOLUME_PATH" --overwrite --profile "$ENVIRONMENT"; then
        error "Failed to upload JAR to Databricks Volume"
    fi
    
    success "JAR uploaded to $VOLUME_PATH"
fi

# Deploy bundle
info "Deploying bundle to $ENVIRONMENT..."

DEPLOY_CMD="databricks bundle deploy -t $ENVIRONMENT"

if [ "$BUILD" = true ]; then
    DEPLOY_CMD="$DEPLOY_CMD --var=\"jar_version=$VERSION\""
fi

if ! eval "$DEPLOY_CMD"; then
    error "Deployment failed"
fi

success "Bundle deployed successfully to $ENVIRONMENT"

# Get job ID
info "Retrieving job information..."
JOB_NAME="${ENVIRONMENT}-workspace-dbxload-worker"

# This would need to be adjusted based on actual job naming
JOB_INFO=$(databricks jobs list --profile "$ENVIRONMENT" --output json | jq -r ".jobs[] | select(.settings.name | contains(\"dbxload-worker\"))" || true)

if [ -n "$JOB_INFO" ]; then
    JOB_ID=$(echo "$JOB_INFO" | jq -r '.job_id')
    success "Job ID: $JOB_ID"
    
    # Get job URL
    DATABRICKS_HOST=$(databricks auth describe --profile "$ENVIRONMENT" | grep "Host:" | awk '{print $2}')
    JOB_URL="${DATABRICKS_HOST}/#job/${JOB_ID}"
    
    info "Job URL: $JOB_URL"
fi

# Run job if requested
if [ "$RUN_JOB" = true ]; then
    if [ -z "$JOB_ID" ]; then
        error "Cannot run job: Job ID not found"
    fi
    
    info "Triggering job run..."
    
    RUN_OUTPUT=$(databricks jobs run-now --job-id "$JOB_ID" --profile "$ENVIRONMENT" --output json)
    RUN_ID=$(echo "$RUN_OUTPUT" | jq -r '.run_id')
    
    if [ -z "$RUN_ID" ]; then
        error "Failed to trigger job run"
    fi
    
    success "Job run started with ID: $RUN_ID"
    info "View run: ${DATABRICKS_HOST}/#job/${JOB_ID}/run/${RUN_ID}"
    
    # Optionally wait for job completion
    read -p "Do you want to wait for job completion? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        info "Waiting for job completion..."
        databricks jobs wait --run-id "$RUN_ID" --profile "$ENVIRONMENT"
        success "Job completed"
    fi
fi

# Display summary
info "Deployment Summary:"
echo "  Environment: $ENVIRONMENT"
echo "  Version: $VERSION"
if [ -n "$JOB_ID" ]; then
    echo "  Job ID: $JOB_ID"
    echo "  Job URL: $JOB_URL"
fi

success "Deployment complete! 🎉"


#!/bin/bash
set -euo pipefail

# REQUIRED: set your UC Volume destination
CATALOG="demo_test"
SCHEMA="mv_test"
VOLUME="cluster"
DEST_ROOT="/Volumes/${CATALOG}/${SCHEMA}/${VOLUME}/log4j2_backups"

# Identify cluster/node
CLUSTER_ID="${DB_CLUSTER_ID:-unknown}"   # Provided by Databricks at cluster startup
NODE_IP="$(hostname -I | awk '{print $1}' || echo unknown)"
mkdir -p "${DEST_ROOT}/${CLUSTER_ID}"

# Pick the correct log4j2.xml depending on driver vs executor
if [[ "${DB_IS_DRIVER:-}" == "TRUE" ]]; then
  ROLE="driver"
  LOG4J2_PATH="/home/ubuntu/databricks/spark/dbconf/log4j/driver/log4j2.xml"
else
  ROLE="executor"
  LOG4J2_PATH="/home/ubuntu/databricks/spark/dbconf/log4j/executor/log4j2.xml"
fi

DEST_PATH="${DEST_ROOT}/${CLUSTER_ID}/${ROLE}_${NODE_IP}.log4j2.xml"

# Copy if the file exists
if [[ -f "${LOG4J2_PATH}" ]]; then
  cp "${LOG4J2_PATH}" "${DEST_PATH}"
  echo "Copied ${LOG4J2_PATH} -> ${DEST_PATH}"
else
  echo "ERROR: log4j2.xml not found at ${LOG4J2_PATH}" >&2
  exit 1
fi
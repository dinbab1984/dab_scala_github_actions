#!/bin/bash
set -euo pipefail

# REQUIRED: set your UC Volume location
CATALOG="demo_test"
SCHEMA="mv_test"
VOLUME="cluster"
SRC_DIR="/Volumes/${CATALOG}/${SCHEMA}/${VOLUME}/custom_log4j2"
# Expected files:
#   /Volumes/.../custom_log4j2/log4j2-driver.xml     (optional; preferred for driver)
#   /Volumes/.../custom_log4j2/custom.executor.log4j2.xml   (optional; preferred for executors)
#   /Volumes/.../custom_log4j2/custom.driver.log4j2.xml            (fallback if role-specific file not present)

# Determine target paths on the node
if [[ "${DB_IS_DRIVER:-}" == "TRUE" ]]; then
  ROLE="driver"
  TARGET_PATH="/home/ubuntu/databricks/spark/dbconf/log4j/driver/log4j2.xml"
  # Choose best source file for driver
  if [[ -f "${SRC_DIR}/lcustom.driver.log4j2.xml" ]]; then
    SRC_PATH="${SRC_DIR}/custom.driver.log4j2.xml"
  elif [[ -f "${SRC_DIR}/custom.executor.log4j2.xml" ]]; then
    SRC_PATH="${SRC_DIR}/custom.executor.log4j2.xml"
  else
    echo "ERROR: No driver log4j2 file found in ${SRC_DIR}" >&2
    exit 1
  fi
else
  ROLE="executor"
  TARGET_PATH="/home/ubuntu/databricks/spark/dbconf/log4j/executor/log4j2.xml"
  # Choose best source file for executors
  if [[ -f "${SRC_DIR}/custom.executor.log4j2.xml" ]]; then
    SRC_PATH="${SRC_DIR}/custom.executor.log4j2.xml"
  elif [[ -f "${SRC_DIR}/custom.driver.log4j2.xml" ]]; then
    SRC_PATH="${SRC_DIR}/custom.driver.log4j2.xml"
  else
    echo "ERROR: No executor log4j2 file found in ${SRC_DIR}" >&2
    exit 1
  fi
fi

# Backup current config before overwrite
BACKUP_DIR="/local_disk0/log4j2_backup"
mkdir -p "${BACKUP_DIR}"
ts="$(date +%Y%m%d-%H%M%S)"
if [[ -f "${TARGET_PATH}" ]]; then
  cp "${TARGET_PATH}" "${BACKUP_DIR}/log4j2_${ROLE}_${ts}.xml"
fi

# Validate XML (optional; skip if xmllint not available)
if command -v xmllint >/dev/null 2>&1; then
  xmllint --noout "${SRC_PATH}"
fi

# Copy new config into place
cp "${SRC_PATH}" "${TARGET_PATH}"
echo "Installed ${SRC_PATH} -> ${TARGET_PATH} for role=${ROLE}"
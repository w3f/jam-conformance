#!/bin/bash

# Ensure virtualenv is active
source .venv/bin/activate

TARGET=$1
INSTANCES=$2

# Input validation
if [ -z "$TARGET" ]; then
    echo "Usage: ./fuzz_start.sh <target_name> [instances]"
    exit 1
fi

# Create a logs directory if it doesn't exist
mkdir -p logs

# 1. Generate Predictable Log Filename
# Format: logs/Target_YYYY-MM-DD_HH-MM-SS_PID.log
# The PID ($$) ensures that if you start multiple runs effectively at the same time,
# the log files will not collide.
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
LOG_FILE="logs/fuzz_${TARGET}_${TIMESTAMP}_$$.log"

echo "------------------------------------------------"
echo "Starting fuzzing for target: $TARGET"
echo "Logging output to: $LOG_FILE"
echo "------------------------------------------------"

# 2. Start the fuzzer in the background
# Using nohup to ensure it persists if the shell closes
nohup python3 ./fuzz-workflow.py \
    --targets "${INSTANCES}${TARGET}" \
    --report-publish \
    --rand-seed \
    --parallel > "$LOG_FILE" 2>&1 &

FUZZ_PID=$!

echo "Fuzzer process started successfully."
echo "Main PID: $FUZZ_PID"
echo "To follow the logs, run: tail -f $LOG_FILE"

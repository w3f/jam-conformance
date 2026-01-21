#!/bin/bash

source .venv/bin/activate

TARGET=$1
NTFY_TOPIC="${TARGET}-m1"
DATE=$(date +%Y-%m-%d)

if [ -z "$TARGET" ]; then
    echo "Usage: ./fuzz_start.sh <target_name>"
    exit 1
fi

# 1. Determine the next run number
RUN_NUM=$(ls fuzz_${DATE}_${TARGET}_run*.log 2>/dev/null | wc -l)
RUN_NUM=$((RUN_NUM + 1))
LOG_FILE="fuzz_${DATE}_${TARGET}_run${RUN_NUM}.log"

# 2. Send "Started" Notification
curl -d "🚀 Fuzzer Started: $TARGET (Run $RUN_NUM) is now running." "ntfy.sh/$NTFY_TOPIC"

echo "Starting fuzzing for $TARGET (Run $RUN_NUM)..."
echo "Logging to: $LOG_FILE"

# 3. Start the fuzzer in the background
nohup python3 ./fuzz-workflow.py --targets "$TARGET" --report-publish --rand-seed > "$LOG_FILE" 2>&1 &
FUZZ_PID=$!

# 4. Start the watchdog with log snippet
# This waits for the PID, then reads the log file's tail into the notification
nohup sh -c "while kill -0 $FUZZ_PID 2>/dev/null; do sleep 60; done; \
             LOG_SNIPPET=\$(tail -n 5 $LOG_FILE); \
             curl -H \"Title: Fuzzer Finished ($TARGET)\" \
                  -d \"✅ Run $RUN_NUM complete.
                  
Last log lines:
\$LOG_SNIPPET\" \
                  ntfy.sh/$NTFY_TOPIC" > /dev/null 2>&1 &

echo "Fuzzer started with PID: $FUZZ_PID"
echo "You can view the live log with: tail -f $LOG_FILE"

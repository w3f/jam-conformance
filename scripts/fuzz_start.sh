#!/bin/bash

source .venv/bin/activate

TARGET=$1
INSTANCES=$2
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
nohup python3 ./fuzz-workflow.py --targets $INSTANCES$TARGET --report-publish --rand-seed --parallel  > "$LOG_FILE" 2>&1 &
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

echo "Waiting 15 seconds for containers to spin up..."
sleep 15

# 4. Start the Docker Watchdog
# This runs in the background. It watches the containers, not the scripts inside them.
(
    # --- CONFIGURATION ---
    # Update this if you use a different fuzzer image!
    IMAGE_FILTER="jamdottech/pyjamaz:latest"
    # ---------------------

    declare -A ALERTED_CONTAINERS

    while true; do
        # 1. Find all container IDs created from the specific image
        # This works regardless of what command is running inside
        CONTAINERS=$(docker ps -a -q --filter ancestor="$IMAGE_FILTER")

        # If no containers are found yet, wait and try again
        if [ -z "$CONTAINERS" ]; then
            # If the launcher (python script) is dead AND no containers exist, we are done.
            if ! kill -0 $FUZZ_PID 2>/dev/null; then
                 curl -d "✅ Fuzzing workflow finished (No containers found)." "ntfy.sh/$NTFY_TOPIC"
                 break
            fi
            sleep 10
            continue
        fi

        # 2. Iterate through each container found
        for id in $CONTAINERS; do
            # Skip if we already sent a notification for this specific container ID
            if [ "${ALERTED_CONTAINERS[$id]}" == "yes" ]; then
                continue
            fi

            # Inspect the container's external state
            # Returns: <Running (true/false)> <ExitCode> <Name>
            STATE=$(docker inspect -f '{{.State.Running}} {{.State.ExitCode}} {{.Name}}' "$id" 2>/dev/null)
            read is_running exit_code name <<< "$STATE"

            # 3. Check for FAILURES
            # Logic: If it is NOT running, and Exit Code is NOT 0, it crashed.
            if [ "$is_running" == "false" ] && [ "$exit_code" != "0" ]; then
                
                # Grab the last 20 lines of logs (works for any language writing to stdout/stderr)
                LOG_DUMP=$(docker logs --tail 20 "$id" 2>&1)
                
                # Send Notification
                curl -H "Title: ⚠️ Container Failed ($name)" \
                     -H "Tags: warning,docker" \
                     -d "Container exited with error code $exit_code.
                     
Last Log Snippet:
$LOG_DUMP" \
                     "ntfy.sh/$NTFY_TOPIC" > /dev/null 2>&1

                # Mark as alerted to prevent spam
                ALERTED_CONTAINERS[$id]="yes"
            fi
        done

        # 4. Global Exit Condition
        # If the main launcher script is dead...
        if ! kill -0 $FUZZ_PID 2>/dev/null; then
             # ...and check if ALL containers are stopped
             RUNNING_COUNT=$(docker ps -q --filter ancestor="$IMAGE_FILTER" | wc -l)
             if [ "$RUNNING_COUNT" -eq 0 ]; then
                 curl -d "✅ All fuzzing containers have finished." "ntfy.sh/$NTFY_TOPIC"
                 break
             fi
        fi

        sleep 30
    done
) &

WATCHDOG_PID=$!
echo "Docker Watchdog started with PID: $WATCHDOG_PID"
echo "Monitoring containers using image: jamdottech/pyjamaz:latest"

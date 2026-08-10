#!/bin/bash

RUN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

EXEC="${RUN_DIR}/corsika78050Linux_EPOS_urqmd_thin"
STEER_BASE="${RUN_DIR}/Asteer"
LONG_BASE="${RUN_DIR}/longfile"
LOG_BASE="${RUN_DIR}/logs"

INCOMPLETE=()

mkdir -p "$LONG_BASE"
mkdir -p "$LOG_BASE"

cd "$RUN_DIR" || exit 1

for ENERGY in {15..21}
do
    DESTINATION="${LONG_BASE}/longfile${ENERGY}"
    mkdir -p "$DESTINATION"

    for SPECIES in {1..26}
    do
        RUNNUM=$(printf "%06d" "$SPECIES")

        STEER_FILE="${STEER_BASE}/E${ENERGY}/E${ENERGY}.${SPECIES}.steer"

        DAT_FILE="${RUN_DIR}/DAT${RUNNUM}"
        LONG_FILE="${RUN_DIR}/DAT${RUNNUM}.long"
        CER_FILE="${RUN_DIR}/CER${RUNNUM}"

        LOG_FILE="${LOG_BASE}/E${ENERGY}.${SPECIES}.out"

        # Look for a previously completed and relocated .long file
        EXISTING_LONG=$(find "$DESTINATION" \
            -maxdepth 1 \
            -type f \
            -name "DAT${RUNNUM}_E${ENERGY}_*.long" \
            -print -quit)

        if [ -n "$EXISTING_LONG" ] &&
           [ -s "$EXISTING_LONG" ] &&
           grep -Eq "FOR SHOWER[[:space:]]+100([^0-9]|$)" "$EXISTING_LONG"
        then
            echo "Species ${SPECIES} at E${ENERGY} already complete — skipping"
            continue
        fi

        echo "Starting: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "Running species ${SPECIES} at E${ENERGY}"

        if [ ! -f "$STEER_FILE" ]; then
            echo "Finished: $(date '+%Y-%m-%d %H:%M:%S')"
            echo "Species ${SPECIES} at E${ENERGY} not complete"
            INCOMPLETE+=("E${ENERGY}.${SPECIES}")
            continue
        fi

        # Remove partial output left behind by an interruption
        rm -f "$DAT_FILE" "$LONG_FILE" "$CER_FILE"

        "$EXEC" < "$STEER_FILE" > "$LOG_FILE" 2>&1

        echo "Finished: $(date '+%Y-%m-%d %H:%M:%S')"

        if [ ! -s "$LONG_FILE" ]; then
            echo "Species ${SPECIES} at E${ENERGY} not complete"
            INCOMPLETE+=("E${ENERGY}.${SPECIES}")
            continue
        fi

        if ! grep -Eq \
        "FOR SHOWER[[:space:]]+100([^0-9]|$)" \
        "$LONG_FILE"
        then
            echo "Species ${SPECIES} at E${ENERGY} not complete"
            INCOMPLETE+=("E${ENERGY}.${SPECIES}")
            continue
        fi

        DATE_FINISHED=$(date '+%Y-%m-%d')
        NEW_NAME="DAT${RUNNUM}_E${ENERGY}_${DATE_FINISHED}.long"
        FINAL_PATH="${DESTINATION}/${NEW_NAME}"

        mv -f "$LONG_FILE" "$FINAL_PATH"

        if [ -s "$FINAL_PATH" ]; then
            rm -f "$DAT_FILE" "$CER_FILE"
            echo "Renamed and relocated: ${FINAL_PATH}"
        else
            echo "Species ${SPECIES} at E${ENERGY} not complete"
            INCOMPLETE+=("E${ENERGY}.${SPECIES}")
        fi
    done
done

echo "All simulations finished: $(date '+%Y-%m-%d %H:%M:%S')"

if [ ${#INCOMPLETE[@]} -gt 0 ]; then
    echo "Simulations not complete: ${INCOMPLETE[*]}"
else
    echo "All simulations completed successfully."
fi

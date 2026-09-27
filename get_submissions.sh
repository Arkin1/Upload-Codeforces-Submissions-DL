#!/usr/bin/env bash
set -uo pipefail

SUBMISSIONS_PATH="data/submissions"

log() {
    local level="$1"
    shift
    printf '%s [%s] %s\n' "$(date +%H:%M:%S)" "$level" "$*"
}

usage() {
    echo "Usage: $0 <handle> --api_key KEY --api_secret SECRET [--retries N] [--count N]"
    exit 1
}

HANDLE=""
API_KEY=""
API_SECRET=""
RETRIES=3
COUNT=100000

POSITIONAL=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --api_key)
            API_KEY="$2"; shift 2;;
        --api_secret)
            API_SECRET="$2"; shift 2;;
        --retries)
            RETRIES="$2"; shift 2;;
        --count)
            COUNT="$2"; shift 2;;
        -h|--help)
            usage;;
        *)
            POSITIONAL+=("$1"); shift;;
    esac
done

if [[ ${#POSITIONAL[@]} -lt 1 ]]; then
    usage
fi
HANDLE="${POSITIONAL[0]}"

if [[ -z "$API_KEY" || -z "$API_SECRET" ]]; then
    usage
fi

for bin in curl jq; do
    if ! command -v "$bin" >/dev/null 2>&1; then
        echo "Required command '$bin' not found in PATH." >&2
        exit 1
    fi
done

if command -v sha512sum >/dev/null 2>&1; then
    SHA512="sha512sum"
elif command -v shasum >/dev/null 2>&1; then
    SHA512="shasum -a 512"
else
    echo "Required command 'sha512sum' (or 'shasum') not found in PATH." >&2
    exit 1
fi

mkdir -p "$SUBMISSIONS_PATH"

get_submission_view() {
    local idx="$1"
    sleep 2
    local my_time
    my_time=$(date +%s)

    local rand="x1y1x2"
    local hash_input="${rand}/user.status?apiKey=${API_KEY}&count=${COUNT}&from=${idx}&handle=${HANDLE}&includeSources=true&time=${my_time}#${API_SECRET}"
    local hsh
    hsh=$(printf '%s' "$hash_input" | $SHA512 | awk '{print $1}')

    local url="https://codeforces.com/api/user.status?apiKey=${API_KEY}&count=${COUNT}&from=${idx}&handle=${HANDLE}&includeSources=true&time=${my_time}&apiSig=${rand}${hsh}"

    curl -sS -f "$url"
}

fetch_with_retry() {
    local idx="$1"
    local attempt=0
    local response

    while [[ $attempt -le $RETRIES ]]; do
        if response=$(get_submission_view "$idx"); then
            local status
            status=$(printf '%s' "$response" | jq -r '.status')
            if [[ "$status" == "OK" ]]; then
                printf '%s' "$response"
                return 0
            fi
            log WARNING "Retry $attempt / $RETRIES with error: $(printf '%s' "$response" | jq -r '.comment // "unknown error"')"
        else
            log WARNING "Retry $attempt / $RETRIES with error: curl request failed"
        fi
        attempt=$((attempt + 1))
    done

    log ERROR "Number of retries exceeded for context GetSubmissionsUser"
    return 1
}

log INFO "Retrieving submissions for user $HANDLE with max $COUNT submissions per view"

idx=1
tmp_file=$(mktemp)
echo "[]" > "$tmp_file"

while true; do
    response=$(fetch_with_retry "$idx") || exit 1

    view_count=$(printf '%s' "$response" | jq '.result | length')
    if [[ "$view_count" -eq 0 ]]; then
        break
    fi

    log INFO "Retrieved submissions from $idx to $((idx + view_count - 1))"

    merged=$(jq -s '.[0] + .[1].result' "$tmp_file" <(printf '%s' "$response"))
    printf '%s' "$merged" > "$tmp_file"

    idx=$((idx + view_count))
done

log INFO "Retrieved all submissions!"

output_file="${SUBMISSIONS_PATH}/${HANDLE}_submissions.json"
jq '.' "$tmp_file" > "$output_file"
rm -f "$tmp_file"

log INFO "Saved submissions to $output_file"

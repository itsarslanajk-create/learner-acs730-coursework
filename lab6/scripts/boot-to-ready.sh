#!/usr/bin/env bash
# boot-to-ready.sh <label> <host> <start-epoch-seconds>
# Polls http://<host>/ until it answers, then prints the seconds elapsed
# since <start-epoch-seconds> (taken when AWS was asked for the instance).
set -euo pipefail

label=${1:?usage: boot-to-ready.sh <label> <host> <start-epoch>}
host=${2:?usage: boot-to-ready.sh <label> <host> <start-epoch>}
start=${3:?usage: boot-to-ready.sh <label> <host> <start-epoch>}

until curl -fsS -m 2 "http://${host}/" >/dev/null 2>&1; do
  sleep 2
done

echo "${label}: $(( $(date +%s) - start )) seconds"

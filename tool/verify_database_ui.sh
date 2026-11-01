#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fixture_data_root=$(mktemp -d "$PWD/build/ui-fixture-data.XXXXXX")
fixture_id=''
cleanup() {
  local verification_status=$?
  trap - EXIT
  if [[ -n "$fixture_id" ]]; then
    if ! docker stop "$fixture_id" >/dev/null; then verification_status=1; fi
  fi
  if ! rm -r -- "$fixture_data_root"; then verification_status=1; fi
  if [[ "$verification_status" == 0 ]]; then
    printf '%s\n' 'BusyData database UI verification and fixture cleanup passed.'
  fi
  exit "$verification_status"
}
trap cleanup EXIT
fixture_id=$(docker run --rm -d -e POSTGRES_PASSWORD=busydata-ui-fixture -p 127.0.0.1::5432 postgres:17.11)
for attempt in $(seq 1 60); do
  if docker exec "$fixture_id" pg_isready -U postgres >/dev/null 2>&1; then break; fi
  if [[ "$attempt" == 60 ]]; then exit 1; fi
  sleep 1
done
BUSYDATA_TEST_PORT=$(docker port "$fixture_id" 5432/tcp | sed 's/.*://')
export BUSYDATA_TEST_PORT
export XDG_DATA_HOME="$fixture_data_root/database"
env -u WAYLAND_DISPLAY GDK_BACKEND=x11 XDG_SESSION_TYPE=x11 GTK_MODULES=gail:atk-bridge \
  xvfb-run -a dbus-run-session -- flutter test --no-pub integration_test/workbench_database_test.dart -d linux
export XDG_DATA_HOME="$fixture_data_root/performance"
env -u WAYLAND_DISPLAY GDK_BACKEND=x11 XDG_SESSION_TYPE=x11 \
  xvfb-run -a dbus-run-session -- flutter test --no-pub integration_test/workbench_performance_test.dart -d linux

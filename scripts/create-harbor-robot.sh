#!/usr/bin/env bash
# create-harbor-robot.sh
# Usage: ./create-harbor-robot.sh
# Requires: curl, jq or python3 (jq preferred)

set -euo pipefail

HARBOR="http://127.0.0.1:8082"
PROJECT_NAME="cicd-demo"
API_USER="jenkins"
API_PASS="Harbor12345"
ROBOT_NAME="robot-ci-cd-demo"     # change if you want a different robot name

# Check dependencies
if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required. Install it and re-run."
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq not found. Script will try python3 for JSON parsing, but jq is recommended."
  USE_PYTHON=true
else
  USE_PYTHON=false
fi

echo "1) Querying Harbor for project '${PROJECT_NAME}'..."
proj_json=$(curl -sS -u "${API_USER}:${API_PASS}" "${HARBOR}/api/v2.0/projects?project_name=${PROJECT_NAME}")

if [ -z "$proj_json" ]; then
  echo "No response from Harbor API. Is Harbor reachable at ${HARBOR}? Exiting."
  exit 2
fi

if [ "$USE_PYTHON" = false ]; then
  PROJECT_ID=$(echo "$proj_json" | jq -r '.[0].project_id // empty')
else
  PROJECT_ID=$(echo "$proj_json" | python3 -c "import sys,json; j=json.load(sys.stdin); print(j[0].get('project_id','') if isinstance(j,list) and j else '')")
fi

if [ -z "$PROJECT_ID" ]; then
  echo "Could not find project_id for '${PROJECT_NAME}' in API response. Full response:"
  echo "$proj_json" | jq . || echo "$proj_json"
  echo "If your API user lacks permission to view projects you'll need to use a project admin/admin account or create the robot using Harbor UI."
  exit 3
fi

echo "Found project_id: $PROJECT_ID"

echo
echo "2) Creating robot account '${ROBOT_NAME}' in project ${PROJECT_NAME} (project_id ${PROJECT_ID})..."
create_body=$(cat <<EOF
{
  "name": "${ROBOT_NAME}",
  "description": "Robot account for Jenkins CI (created by script)",
  "expires_at": 0,
  "permissions": [
    {"resource": "/project/${PROJECT_NAME}/repository", "action": "push"},
    {"resource": "/project/${PROJECT_NAME}/repository", "action": "pull"}
  ]
}
EOF
)

# Create robot and capture HTTP status and body
resp=$(curl -sS -u "${API_USER}:${API_PASS}" -w "\n%{http_code}" -X POST \
  -H "Content-Type: application/json" \
  -d "${create_body}" \
  "${HARBOR}/api/v2.0/projects/${PROJECT_ID}/robots")

status=$(printf "%s" "$resp" | tail -n1)
body=$(printf "%s" "$resp" | sed '$d')

echo "HTTP status: $status"
echo "Response body:"
if command -v jq >/dev/null 2>&1; then
  echo "$body" | jq .
else
  echo "$body"
fi

if [ "$status" != "201" ] && [ "$status" != "200" ]; then
  echo
  echo "Robot creation failed or requires higher privileges. Common reasons:"
  echo "- Your API user (jenkins) is not a project owner or admin and cannot create robot accounts."
  echo "- Use a project admin or the Harbor UI to create the robot, or login as admin and rerun this script."
  echo
  echo "If you prefer the UI: Login as admin -> Projects -> cicd-demo -> Robot Accounts -> NEW ROBOT ACCOUNT (copy token shown once)."
  exit 4
fi

# Try to extract token/secret from the response
if command -v jq >/dev/null 2>&1; then
  token=$(echo "$body" | jq -r '.secret // .token // .plain_secret // .data.secret // .access_token // empty')
  robot_account_name=$(echo "$body" | jq -r '.name // .robot // empty')
else
  token=$(echo "$body" | python3 -c "import sys,json; j=json.load(sys.stdin); print(j.get('secret') or j.get('token') or j.get('plain_secret') or '')")
  robot_account_name=$(echo "$body" | python3 -c "import sys,json; j=json.load(sys.stdin); print(j.get('name',''))")
fi

if [ -z "$robot_account_name" ]; then
  # Attempt to guess name
  robot_account_name="$ROBOT_NAME"
fi

echo
if [ -n "$token" ]; then
  echo "Robot created. Robot name: ${robot_account_name}"
  echo "Robot token (copy this now; token is shown only once):"
  echo
  echo "$token"
  echo
  echo "Add to Jenkins as 'Username with password' credential:"
  echo "  Username: robot\$${robot_account_name}"
  echo "  Password: ${token}"
else
  echo "Robot creation response did not include a parseable token in the usual fields."
  echo "Check the response above for the token (fields may differ by Harbor version). If token isn't visible, create the robot via UI and copy token from UI."
fi

echo
echo "3) Test docker login & push (run these on the Jenkins agent that runs Docker):"
echo "Replace <ROBOT_TOKEN> and <ROBOT_NAME> with values above."
cat <<'EOF'
# Example commands (paste and run on the Jenkins agent):
echo "<ROBOT_TOKEN>" | docker login 127.0.0.1:8082 -u "robot$robot-ci-cd" --password-stdin
docker pull busybox:latest
docker tag busybox:latest 127.0.0.1:8082/cicd-demo/busybox-test:ci-test
docker push 127.0.0.1:8082/cicd-demo/busybox-test:ci-test
EOF

echo
echo "Notes:"
echo "- If docker push fails with TLS/insecure registry errors, add 127.0.0.1:8082 to the Docker daemon's insecure registries and restart Docker."
echo "- If the script returned a 403 at robot creation: create the robot with Harbor UI using an admin/project-owner account."
echo
echo "Done."

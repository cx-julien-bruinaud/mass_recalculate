#!/bin/bash
# Script to trigger SCA recalculation for all projects and branches in a CxOne tenant
# Usage: ./mass_recalc.sh tenant env
# CX1_CLIENT_ID and CX1_CLIENT_SECRET are environment variables required for authentication, this is an OAuth2 client that must have the ast-scanner role assigned
# If your tenant has the New IAM enabled, you must add the client at the tenant level (under Global Settings > Settings > Authorization)
# CX1_TENANT is your CxOne tenant name
# CX1_ENV is your CxOne environment name

CX1_CLIENT_ID=${CX1_CLIENT_ID}
CX1_CLIENT_SECRET=${CX1_CLIENT_SECRET}

# Check if required environment variables are set
if [ -z "$CX1_CLIENT_ID" ] || [ -z "$CX1_CLIENT_SECRET" ]; then
    echo "Error: CX1_CLIENT_ID and CX1_CLIENT_SECRET environment variables must be set."
    exit 1
fi

# Check if tenant and environment arguments are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 tenant env"
    exit 1
fi
# check that the arguments are strings and sanitize them
if ! [[ "$1" =~ ^[a-zA-Z0-9_-]+$ ]] || ! [[ "$2" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "Error: tenant and env arguments must be alphanumeric strings (letters, numbers, underscores, or hyphens)."
    exit 1
fi
CX1_TENANT=$1
CX1_ENV=$2

# Get access token from CxOne
ACCESS_TOKEN=$(curl -s -X POST "https://${CX1_ENV}.iam.checkmarx.net/auth/realms/${CX1_TENANT}/protocol/openid-connect/token" \
  --header 'Content-Type: application/x-www-form-urlencoded' \
  --header 'Accept: application/json' \
  --data-urlencode "client_id=$CX1_CLIENT_ID" \
  --data-urlencode 'grant_type=client_credentials' \
  --data-urlencode "client_secret=${CX1_CLIENT_SECRET}" | jq -r .access_token)

if [ -z "$ACCESS_TOKEN" ] || [ "$ACCESS_TOKEN" = "null" ]; then
    echo "Error: Failed to obtain access token"
    exit 1
else
    echo "Successfully obtained access token"
fi

# Getting the list of projects to recalculate
echo "Getting the list of projects to recalculate..."
echo "----------------------------------------"

# First, get the total count of projects
PROJECTS=$(curl -s -X GET "https://${CX1_ENV}.ast.checkmarx.net/api/projects?limit=1" \
    --header "Authorization: Bearer ${ACCESS_TOKEN}" \
    --header "Accept: application/json")

#echo "$PROJECTS" | jq .

PROJECT_COUNT=$(echo "$PROJECTS" | jq -r '.totalCount')

echo "Total projects found: $PROJECT_COUNT"
echo "----------------------------------------"
# Then fetch all projects based on the total count and loop through them

OFFSET=0
LIMIT=20

while [ $OFFSET -lt $PROJECT_COUNT ]; do

    if [ $((OFFSET + LIMIT)) -gt $PROJECT_COUNT ]; then
        MAX=$PROJECT_COUNT
    else
        MAX=$((OFFSET + LIMIT))
    fi

    echo "Fetching projects $((OFFSET + 1)) to $MAX ..."
    PROJECTS_BATCH=$(curl -s -X GET "https://${CX1_ENV}.ast.checkmarx.net/api/projects?limit=${LIMIT}&offset=${OFFSET}" \
        --header "Authorization: Bearer ${ACCESS_TOKEN}" \
        --header "Accept: application/json")

    #echo "$PROJECTS_BATCH" | jq -r
    
    # Loop through each project in the batch
    echo "$PROJECTS_BATCH" | jq -r '.projects.[].id' | while read -r project; do
        echo "Recalculating project ID: $project"

        echo " Getting the list of branches for project ID: $project"
        # Get branches for the project
        BRANCHES=$(curl -s -X GET "https://${CX1_ENV}.ast.checkmarx.net/api/projects/branches?offset=0&limit=20&project-id=${project}" \
            --header 'Content-Type: application/x-www-form-urlencoded' \
            --header "Authorization: Bearer ${ACCESS_TOKEN}" \
            --header "Accept: application/json")
        echo "$BRANCHES" | jq -r
        # Returns an array of branch names like ["master","development","feature-xyz"]
        # If not empty
        if [ "$(echo "$BRANCHES" | jq -r 'length')" -gt 0 ]; then
            # Get the first branch name
            echo "  Branches found for project ID: $project"
        else
            echo "  No branch found for project ID: $project, skipping..."
            continue
        fi

        # For each branch, trigger recalculation
        echo "$BRANCHES" | jq -r '.[]' | while read -r branch; do
            echo " Recalculating project ID: $project, branch: $branch"

            # Trigger recalculation for the project and branch
            RECALC_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "https://${CX1_ENV}.ast.checkmarx.net/api/scans/recalculate" \
                --header "Authorization: Bearer ${ACCESS_TOKEN}" \
                --header "Accept: application/json" \
                --header "Content-Type: application/json" \
                --data '{
                "project_id": "'"$project"'",
                    "branch": "'"$branch"'",
                    "engines": [
                        "sca"
                    ]
                }')

            if [ "$RECALC_RESPONSE" -eq 201 ] ; then
                echo "Successfully triggered recalculation for project ID: $project"
            else
                echo "Failed to trigger recalculation for project ID: $project, HTTP status code: $RECALC_RESPONSE"
            fi
            # Avoid hitting rate limits
            sleep 1


        done
        echo "----------------------------------------"

    done

    OFFSET=$((OFFSET + LIMIT))
done

echo "----------------------------------------"
echo "Recalculation completed!"
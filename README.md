# Mass Recalculate Script

## Overview

The `mass_recalc.sh` script is designed to trigger SCA (Software Composition Analysis) recalculation for all projects and branches in a CxOne tenant. This is useful for bulk operations when you need to refresh SCA results across your entire organization.

## Prerequisites

### Required Dependencies
- `curl` - for making HTTP requests
- `jq` - for JSON parsing and manipulation

### Authentication Requirements
- **CxOne OAuth2 Client**: You must have an OAuth2 client configured with the `ast-scanner` role
- **New IAM Compatibility**: If your tenant has the New IAM enabled, the client must be added at the tenant level under Global Settings > Settings > Authorization

### Environment Variables
The following environment variables must be set before running the script:

```bash
export CX1_CLIENT_ID="your-client-id"
export CX1_CLIENT_SECRET="your-client-secret"
```

## Usage

```bash
./mass_recalc.sh <tenant> <environment>
```

### Parameters
- `tenant`: Your CxOne tenant name (alphanumeric, underscores, and hyphens allowed)
- `environment`: Your CxOne environment name (alphanumeric, underscores, and hyphens allowed)

### Example
```bash
./mass_recalc.sh mycompany us
```

## What the Script Does

1. **Authentication**: Obtains an OAuth2 access token from CxOne using client credentials
2. **Project Discovery**: Retrieves all projects in the tenant with pagination support (20 projects per batch)
3. **Branch Enumeration**: For each project, fetches all available branches
4. **SCA Recalculation**: Triggers SCA recalculation for each project-branch combination
5. **Rate Limiting**: Includes a 1-second delay between API calls to avoid hitting rate limits

## Script Features

### Input Validation
- Checks for required environment variables
- Validates command-line arguments (exactly 2 parameters required)
- Sanitizes tenant and environment inputs to prevent injection attacks

### Error Handling
- Validates authentication token retrieval
- Checks HTTP response codes for recalculation requests
- Provides detailed logging of successes and failures

### Performance Optimization
- Uses pagination to handle large numbers of projects efficiently
- Batches project retrieval in groups of 20
- Implements rate limiting to respect API constraints

## Output

The script provides detailed logging including:
- Total number of projects found
- Progress indicators for batch processing
- Individual project and branch processing status
- Success/failure status for each recalculation request
- HTTP status codes for debugging failed requests

### Sample Output
```
Successfully obtained access token
Getting the list of projects to recalculate...
----------------------------------------
Total projects found: 45
----------------------------------------
Fetching projects 1 to 20 ...
Recalculating project ID: 12345-abcd-6789-efgh
 Getting the list of branches for project ID: 12345-abcd-6789-efgh
  Branches found for project ID: 12345-abcd-6789-efgh
 Recalculating project ID: 12345-abcd-6789-efgh, branch: main
Successfully triggered recalculation for project ID: 12345-abcd-6789-efgh
----------------------------------------
```

## API Endpoints Used

- **Authentication**: `https://{env}.iam.checkmarx.net/auth/realms/{tenant}/protocol/openid-connect/token`
- **Projects**: `https://{env}.ast.checkmarx.net/api/projects`
- **Branches**: `https://{env}.ast.checkmarx.net/api/projects/branches`
- **Recalculation**: `https://{env}.ast.checkmarx.net/api/scans/recalculate`

## Error Codes

- **Exit 1**: Missing required environment variables
- **Exit 1**: Invalid command-line arguments
- **Exit 1**: Failed to obtain authentication token

## Security Considerations

- Environment variables are used to avoid hardcoding credentials
- Input sanitization prevents command injection
- OAuth2 client credentials flow provides secure authentication

## Troubleshooting

### Common Issues

1. **Authentication Failure**
   - Verify `CX1_CLIENT_ID` and `CX1_CLIENT_SECRET` are correctly set
   - Ensure the OAuth2 client has the `ast-scanner` role
   - Check if the client is configured at the tenant level for New IAM

2. **Rate Limiting**
   - The script includes 1-second delays, but you may need to increase this for high-volume tenants
   - Monitor for HTTP 429 responses

3. **Network Issues**
   - Verify connectivity to CxOne endpoints
   - Check firewall and proxy configurations

### Debugging

To enable verbose output, you can uncomment the `echo` and `jq` debug lines in the script:
```bash
# Uncomment these lines for debugging
#echo "$PROJECTS" | jq .
#echo "$PROJECTS_BATCH" | jq -r
```

## Best Practices

- Run during off-peak hours to minimize impact on other operations
- Monitor the output for failed recalculations and retry if necessary
- Consider running on a subset of projects first to validate configuration
- Ensure adequate API rate limits for your tenant size

## License

This script is provided as-is for CxOne API automation purposes and comes with no warranty.
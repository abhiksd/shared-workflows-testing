# GitHub Actions Job Output Troubleshooting Guide

## Issue: Job Outputs Not Passing Between Jobs

When job outputs are not properly passed from one job to another, it can cause parameters to be empty in downstream jobs.

## Common Symptoms

```bash
# In validate-environment job (works fine):
📊 Environment validation results:
   - AKS cluster name: my-cluster
   - AKS resource group: my-resource-group

# In deploy job (outputs are empty):
🔍 Validating AKS deployment parameters...
❌ ERROR: aks_resource_group is empty or not provided
```

## Root Causes

### 1. **Conditional Output Setting**
**Problem:** Outputs only set when certain conditions are met
```bash
# WRONG - outputs only set when SHOULD_DEPLOY is true
if [ "$SHOULD_DEPLOY" == "true" ]; then
  AKS_CLUSTER="${{ secrets.AKS_CLUSTER_NAME_DEV }}"
  AKS_RG="${{ secrets.AKS_RESOURCE_GROUP_DEV }}"
fi
```

**Solution:** Always set outputs for valid environments
```bash
# CORRECT - outputs always set for environment
case "$TARGET_ENV" in
  "dev")
    AKS_CLUSTER="${{ secrets.AKS_CLUSTER_NAME_DEV }}"
    AKS_RG="${{ secrets.AKS_RESOURCE_GROUP_DEV }}"
    # Then check if deployment should proceed
    ;;
esac
```

### 2. **Missing Job Dependencies**
**Problem:** Downstream job doesn't depend on upstream job
```yaml
# WRONG
deploy:
  needs: [setup, build]  # Missing validate-environment
```

**Solution:** Include all required dependencies
```yaml
# CORRECT
deploy:
  needs: [validate-environment, setup, build]
```

### 3. **Incorrect Output Reference**
**Problem:** Wrong syntax for referencing job outputs
```yaml
# WRONG
aks_cluster_name: ${{ needs.validate_environment.outputs.aks_cluster_name }}

# CORRECT
aks_cluster_name: ${{ needs.validate-environment.outputs.aks_cluster_name }}
```

### 4. **Step ID Mismatch**
**Problem:** Output step ID doesn't match job output definition
```yaml
# Job outputs reference wrong step ID
outputs:
  aks_cluster_name: ${{ steps.check.outputs.aks_cluster_name }}  # Step ID: check

# But step has different ID
- name: Validate environment
  id: validate  # Different ID!
```

## Fixed Implementation

### Job Output Definition
```yaml
validate-environment:
  outputs:
    should_deploy: ${{ steps.check.outputs.should_deploy }}
    target_environment: ${{ steps.check.outputs.target_environment }}
    aks_cluster_name: ${{ steps.check.outputs.aks_cluster_name }}
    aks_resource_group: ${{ steps.check.outputs.aks_resource_group }}
  steps:
    - name: Validate environment and branch rules
      id: check  # Must match outputs reference
      run: |
        # Always set outputs for valid environments
        case "$TARGET_ENV" in
          "dev")
            AKS_CLUSTER="${{ secrets.AKS_CLUSTER_NAME_DEV }}"
            AKS_RG="${{ secrets.AKS_RESOURCE_GROUP_DEV }}"
            ;;
        esac
        
        # Always write outputs (even if empty)
        echo "aks_cluster_name=$AKS_CLUSTER" >> $GITHUB_OUTPUT
        echo "aks_resource_group=$AKS_RG" >> $GITHUB_OUTPUT
```

### Consuming Job
```yaml
deploy:
  needs: [validate-environment, setup, build]  # Include all dependencies
  steps:
    - name: Debug outputs
      run: |
        echo "Cluster: ${{ needs.validate-environment.outputs.aks_cluster_name }}"
        echo "RG: ${{ needs.validate-environment.outputs.aks_resource_group }}"
    
    - name: Deploy
      uses: ./.github/actions/helm-deploy
      with:
        aks_cluster_name: ${{ needs.validate-environment.outputs.aks_cluster_name }}
        aks_resource_group: ${{ needs.validate-environment.outputs.aks_resource_group }}
```

## Debugging Steps

### 1. **Add Debug Output in Source Job**
```yaml
- name: Debug outputs before setting
  run: |
    echo "About to set outputs:"
    echo "   - AKS_CLUSTER: $AKS_CLUSTER"
    echo "   - AKS_RG: $AKS_RG"
    echo "aks_cluster_name=$AKS_CLUSTER" >> $GITHUB_OUTPUT
    echo "aks_resource_group=$AKS_RG" >> $GITHUB_OUTPUT
```

### 2. **Add Debug Output in Consumer Job**
```yaml
- name: Debug received outputs
  run: |
    echo "Received from validate-environment:"
    echo "   - should_deploy: ${{ needs.validate-environment.outputs.should_deploy }}"
    echo "   - target_environment: ${{ needs.validate-environment.outputs.target_environment }}"
    echo "   - aks_cluster_name: ${{ needs.validate-environment.outputs.aks_cluster_name }}"
    echo "   - aks_resource_group: ${{ needs.validate-environment.outputs.aks_resource_group }}"
```

### 3. **Check Job Status**
Ensure the source job completed successfully:
```yaml
if: needs.validate-environment.result == 'success'
```

### 4. **Validate Job Context**
```yaml
- name: Debug job context
  run: |
    echo "Job context:"
    echo '${{ toJson(needs) }}'
```

## Common Patterns and Solutions

### Pattern 1: Environment-Specific Outputs
```yaml
# WRONG - conditionally set
if [ "$ENV" == "dev" ]; then
  echo "cluster=$DEV_CLUSTER" >> $GITHUB_OUTPUT
fi

# CORRECT - always set with fallback
case "$ENV" in
  "dev") CLUSTER="$DEV_CLUSTER" ;;
  *) CLUSTER="" ;;
esac
echo "cluster=$CLUSTER" >> $GITHUB_OUTPUT
```

### Pattern 2: Multi-Job Dependencies
```yaml
# Ensure all upstream jobs are listed
deploy:
  needs: [validate-environment, setup, build, security-scan]
  if: |
    needs.validate-environment.outputs.should_deploy == 'true' &&
    needs.setup.outputs.should_deploy == 'true' &&
    !failure() && !cancelled()
```

### Pattern 3: Conditional vs Required Outputs
```yaml
# For optional outputs
aks_cluster_name: ${{ needs.validate-environment.outputs.aks_cluster_name || 'default-cluster' }}

# For required outputs (with validation)
- name: Validate required outputs
  run: |
    if [ -z "${{ needs.validate-environment.outputs.aks_cluster_name }}" ]; then
      echo "ERROR: aks_cluster_name is required but empty"
      exit 1
    fi
```

## Prevention Checklist

✅ **Job outputs always set for valid conditions**  
✅ **Step IDs match output references**  
✅ **Job dependencies include all required upstream jobs**  
✅ **Output syntax uses correct job names (hyphens, not underscores)**  
✅ **Source job completes successfully before consumer runs**  
✅ **Debug outputs added for troubleshooting**  

## Testing Outputs Locally

You can test output behavior using act:
```bash
# Install act (GitHub Actions local runner)
curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash

# Run specific job
act -j validate-environment

# Run with secrets
act -j validate-environment --secret-file .secrets
```

## Related Files

- `.github/workflows/shared-deploy.yml` - Main workflow with job dependencies
- Job outputs now always set for valid environments regardless of deployment approval
- Enhanced debugging added to identify output passing issues

The output passing mechanism is now robust and includes comprehensive debugging to identify and resolve issues quickly.
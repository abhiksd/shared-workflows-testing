# Artifact Download Troubleshooting Guide

## Error: No artifact name specified, downloading all artifacts / Unable to find any artifacts

This error occurs when GitHub Actions tries to download artifacts but either no artifacts exist or the download configuration is incorrect.

## Root Cause Analysis

### 1. **No Artifact Name Specified**
```
Run actions/download-artifact@v3
No artifact name specified, downloading all artifacts
Creating an extra directory for each artifact that is being downloaded
Unable to find any artifacts for the associated workflow
There were 0 artifacts downloaded
```

**Cause:** The `actions/download-artifact` step is called without a `name` parameter, so it tries to download all artifacts.

### 2. **No Artifacts Available**
**Cause:** The artifact upload step failed or didn't run in a previous job.

## Fixed Architecture

### Previous Issue (Redundant Downloads)
The workflow had **two artifact download mechanisms**:
1. Direct download in workflow (✅ correct)
2. Download inside docker-build-push action (❌ redundant)

### Current Solution
**Single Download Pattern:**
```yaml
# In workflow (.github/workflows/shared-deploy.yml)
- name: Download Maven build artifacts
  if: inputs.application_type == 'java-springboot'
  uses: actions/download-artifact@v4
  with:
    name: ${{ needs.maven-build.outputs.jar_artifact }}
    path: ${{ inputs.build_context }}

# Docker action expects artifacts to already be present
- name: Build and push Docker image
  uses: ./.github/actions/docker-build-push
  with:
    jar_artifact_name: ${{ needs.maven-build.outputs.jar_artifact }}  # For debugging only
```

## Troubleshooting Steps

### 1. **Verify Artifact Upload**
Check if the Maven build job successfully uploaded artifacts:

```yaml
# In maven-build action
- name: Upload build artifacts
  if: inputs.upload_artifacts == 'true'
  uses: actions/upload-artifact@v4
  with:
    name: ${{ steps.setup.outputs.artifact_name }}
    path: ${{ inputs.build_context }}/target/*.jar
    retention-days: 1
```

### 2. **Check Job Dependencies**
Ensure the build job completes before docker build:

```yaml
build:
  needs: [setup, sonar-scan, checkmarx-scan]
  # ... maven build steps

docker-build:
  needs: [setup, build]  # ✅ Depends on build job
  steps:
    - name: Download Maven build artifacts
      uses: actions/download-artifact@v4
      with:
        name: ${{ needs.maven-build.outputs.jar_artifact }}  # ✅ Reference build job output
```

### 3. **Verify Artifact Names Match**
Check that upload and download use the same artifact name:

```yaml
# Upload (in maven-build)
outputs:
  jar_artifact: ${{ steps.upload.outputs.artifact_name }}

# Download (in workflow)
with:
  name: ${{ needs.maven-build.outputs.jar_artifact }}
```

### 4. **Debug Artifact Availability**
Add debugging step to check available artifacts:

```yaml
- name: Debug artifacts
  run: |
    echo "Expected artifact: ${{ needs.maven-build.outputs.jar_artifact }}"
    echo "Available artifacts:"
    curl -H "Authorization: token ${{ github.token }}" \
         "https://api.github.com/repos/${{ github.repository }}/actions/runs/${{ github.run_id }}/artifacts" | \
         jq '.artifacts[].name'
```

## Common Issues and Solutions

### 1. **Conditional Upload/Download Mismatch**
```yaml
# WRONG - Upload condition doesn't match download condition
upload_artifacts: 'false'  # Maven build skips upload
# But download still expects artifact

# CORRECT - Match conditions
- name: Download Maven build artifacts
  if: inputs.application_type == 'java-springboot' && needs.maven-build.outputs.jar_artifact != ''
```

### 2. **Job Failure Before Upload**
```yaml
# If maven-build fails, no artifacts are uploaded
needs: [setup, sonar-scan, checkmarx-scan, maven-build]  # All must succeed
```

**Solution:** Check for build failures in previous jobs.

### 3. **Artifact Retention Expired**
```yaml
# Artifacts expire after retention period
retention-days: 1  # Very short retention

# For debugging, increase retention
retention-days: 5
```

### 4. **Wrong Artifact Path**
```yaml
# WRONG - Downloads to wrong location
path: /tmp/artifacts

# CORRECT - Downloads to build context
path: ${{ inputs.build_context }}
```

## Enhanced Error Handling

The docker-build-push action now provides better error messages:

```bash
❌ ERROR: No executable JAR files found in build context!
📋 This usually means:
   1. Maven build failed or artifacts were not uploaded
   2. Artifact download failed in the calling workflow
   3. Wrong build context path specified
   4. JAR artifact name mismatch between build and download

🔍 Debugging information:
   - Build context: apps/java-app
   - Expected JAR artifact: java-app-build-artifacts-abc123
   - Current working directory: /home/runner/work/repo/repo/apps/java-app

💡 Check the 'Download Maven build artifacts' step in your workflow
```

## Verification Commands

### Local Testing
```bash
# Check if JAR was built
ls -la apps/java-app/target/*.jar

# Verify JAR content
jar -tf apps/java-app/target/app.jar | head -10
```

### GitHub Actions Debugging
```yaml
- name: Debug build context
  run: |
    echo "=== Build Context Contents ==="
    ls -la ${{ inputs.build_context }}
    
    echo "=== JAR Files ==="
    find ${{ inputs.build_context }} -name "*.jar" -type f
    
    echo "=== Expected Artifact ==="
    echo "${{ needs.maven-build.outputs.jar_artifact }}"
```

## Prevention Checklist

✅ **Maven build job succeeds and uploads artifacts**  
✅ **Artifact upload and download use same name**  
✅ **Job dependencies are correctly configured**  
✅ **Download conditions match upload conditions**  
✅ **Build context paths are consistent**  
✅ **Sufficient artifact retention period**

## Related Files

- `.github/workflows/shared-deploy.yml` - Main workflow with artifact download
- `.github/actions/maven-build/action.yml` - Artifact upload
- `.github/actions/docker-build-push/action.yml` - Expects artifacts to be present
- Artifacts are now downloaded once by the workflow, not by individual actions

The artifact download process is now streamlined with clear error messages and better debugging information.
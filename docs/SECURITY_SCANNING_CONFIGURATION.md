# Security Scanning Configuration Guide

## 🔒 **Repository-Level Security Scan Control**

This guide explains how to enable or disable SonarQube and Checkmarx security scanning using repository-level variables without modifying workflow code.

## 🎛️ **Repository Variables**

### **Required Variables**

Set these variables at the **Repository level** in GitHub Settings:

| Variable Name | Type | Default | Description |
|---------------|------|---------|-------------|
| `SONAR_ENABLED` | `string` | `"true"` | Enable/disable SonarQube scanning |
| `CHECKMARX_ENABLED` | `string` | `"true"` | Enable/disable Checkmarx scanning |

### **How to Set Repository Variables**

1. **Navigate to Repository Settings**:
   ```
   GitHub Repository → Settings → Secrets and variables → Actions → Variables tab
   ```

2. **Create New Repository Variables**:
   ```
   Variable name: SONAR_ENABLED
   Value: false  (to disable) or true (to enable)
   
   Variable name: CHECKMARX_ENABLED  
   Value: false  (to disable) or true (to enable)
   ```

## 🚀 **Usage Examples**

### **Example 1: Disable Both Scans**
```
Repository Variables:
├── SONAR_ENABLED = "false"
└── CHECKMARX_ENABLED = "false"

Result: Both scans will be skipped, deployment proceeds
```

### **Example 2: Enable Only SonarQube**
```
Repository Variables:
├── SONAR_ENABLED = "true"
└── CHECKMARX_ENABLED = "false"

Result: Only SonarQube runs, Checkmarx is skipped
```

### **Example 3: Enable Only Checkmarx**
```
Repository Variables:
├── SONAR_ENABLED = "false"
└── CHECKMARX_ENABLED = "true"

Result: Only Checkmarx runs, SonarQube is skipped
```

### **Example 4: Enable Both (Default)**
```
Repository Variables:
├── SONAR_ENABLED = "true"  (or not set - defaults to true)
└── CHECKMARX_ENABLED = "true"  (or not set - defaults to true)

Result: Both scans run as normal
```

## 🔄 **Workflow Behavior**

### **When Scans are Enabled (`true`)**
```yaml
# SonarQube Job
sonar-scan:
  steps:
    - name: Check if SonarQube is enabled
      run: echo "✅ SonarQube scanning is enabled - proceeding"
    
    - name: SonarQube Scan
      uses: ./.github/actions/sonar-scan
      # ... scan executes normally
```

### **When Scans are Disabled (`false`)**
```yaml
# SonarQube Job  
sonar-scan:
  steps:
    - name: Check if SonarQube is enabled
      run: echo "⏭️ SonarQube scanning is disabled - skipping"
      outputs:
        scan_status: "SKIPPED"
    
    # All other steps are skipped conditionally
```

## 📊 **Scan Status Handling**

### **Status Values**
| Status | Description | Deployment Impact |
|--------|-------------|-------------------|
| `PASSED` | Scan completed successfully | ✅ Deployment proceeds |
| `FAILED` | Scan found issues/failed | ❌ Deployment blocked |
| `SKIPPED` | Scan was disabled | ✅ Deployment proceeds |

### **Deployment Logic**
```yaml
# Build and Deploy jobs proceed if:
if: |
  (sonar-scan.outputs.scan_status == 'PASSED' || sonar-scan.outputs.scan_status == 'SKIPPED') &&
  (checkmarx-scan.outputs.scan_status == 'PASSED' || checkmarx-scan.outputs.scan_status == 'SKIPPED')
```

## 🔍 **Workflow Integration**

### **Shared Deployment Workflow**
```yaml
# .github/workflows/shared-deploy.yml
sonar-scan:
  steps:
    - name: Check if SonarQube is enabled
      id: check_enabled
      run: |
        SONAR_ENABLED="${{ vars.SONAR_ENABLED || 'true' }}"
        if [[ "$SONAR_ENABLED" == "false" ]]; then
          echo "scan_status=SKIPPED" >> $GITHUB_OUTPUT
          echo "enabled=false" >> $GITHUB_OUTPUT
        else
          echo "enabled=true" >> $GITHUB_OUTPUT
        fi
    
    - name: SonarQube Scan
      if: steps.check_enabled.outputs.enabled == 'true'
      uses: ./.github/actions/sonar-scan
```

### **PR Security Check Workflow**
```yaml
# .github/workflows/pr-security-check.yml
- name: SonarQube Scan
  uses: ./.github/actions/sonar-scan
  with:
    sonar_enabled: ${{ vars.SONAR_ENABLED || 'true' }}

- name: Checkmarx Scan  
  uses: ./.github/actions/checkmarx-scan
  with:
    checkmarx_enabled: ${{ vars.CHECKMARX_ENABLED || 'true' }}
```

## 🛠️ **Scenarios & Use Cases**

### **Scenario 1: Temporary Disable During Incident**
```bash
# Quick disable during production incident
Repository Variables:
├── SONAR_ENABLED = "false"
└── CHECKMARX_ENABLED = "false"

# All new deployments skip security scans
# Re-enable after incident is resolved
```

### **Scenario 2: SonarQube Server Maintenance**
```bash
# SonarQube server is down for maintenance
Repository Variables:
├── SONAR_ENABLED = "false"      # Disable SonarQube
└── CHECKMARX_ENABLED = "true"   # Keep Checkmarx active

# Deployments continue with Checkmarx-only scanning
```

### **Scenario 3: License/Cost Management**
```bash
# Temporarily disable expensive scans
Repository Variables:
├── SONAR_ENABLED = "true"       # Free/cheaper option
└── CHECKMARX_ENABLED = "false"  # Expensive commercial tool

# Maintain basic quality gates while reducing costs
```

### **Scenario 4: Development Environment**
```bash
# Development/testing repository
Repository Variables:
├── SONAR_ENABLED = "false"      # Skip for faster iterations
└── CHECKMARX_ENABLED = "false"  # Skip for faster iterations

# Faster development cycles without security overhead
```

## 📋 **Configuration Checklist**

### **✅ Setup Checklist**
- [ ] Set `SONAR_ENABLED` repository variable
- [ ] Set `CHECKMARX_ENABLED` repository variable  
- [ ] Test deployment with scans disabled
- [ ] Verify workflow logs show skip messages
- [ ] Confirm deployment proceeds successfully

### **✅ Verification Commands**
```bash
# Check workflow run logs for skip messages
# Look for these log entries:

# When SonarQube is disabled:
"⏭️ SonarQube scanning is disabled - skipping"

# When Checkmarx is disabled:  
"⏭️ Checkmarx scanning is disabled - skipping"

# When scans are enabled:
"✅ SonarQube scanning is enabled - proceeding"
"✅ Checkmarx scanning is enabled - proceeding"
```

## 🚨 **Important Notes**

### **⚠️ Security Considerations**
1. **Only disable scans temporarily** - Security scanning is important for production code
2. **Document the reason** when disabling scans (incident, maintenance, etc.)
3. **Re-enable scans** as soon as the temporary condition is resolved
4. **Monitor deployments** when scans are disabled to ensure quality

### **⚠️ Default Behavior**
- If variables are **not set**, both scans are **enabled by default**
- If variables are **empty** or **invalid**, both scans are **enabled by default**
- Only the exact string `"false"` disables scanning

### **⚠️ Case Sensitivity**
```bash
# These disable scanning:
SONAR_ENABLED = "false"     ✅
CHECKMARX_ENABLED = "false" ✅

# These do NOT disable scanning:
SONAR_ENABLED = "False"     ❌ (wrong case)
SONAR_ENABLED = "FALSE"     ❌ (wrong case)  
SONAR_ENABLED = "0"         ❌ (not "false")
SONAR_ENABLED = ""          ❌ (empty, defaults to true)
```

## 🔧 **Troubleshooting**

### **Issue: Scans Still Running When Disabled**
**Solution:**
1. Verify variable spelling: `SONAR_ENABLED`, `CHECKMARX_ENABLED`
2. Ensure value is exactly `"false"` (lowercase)
3. Check workflow logs for enable/disable messages
4. Wait for next workflow run (changes take effect on new runs)

### **Issue: Deployment Blocked When Scans Disabled**
**Solution:**
1. Check if scan jobs are properly outputting `SKIPPED` status
2. Verify deployment conditions accept `SKIPPED` status
3. Review workflow logs for unexpected failures

### **Issue: Variables Not Taking Effect**
**Solution:**
1. Ensure variables are set at **Repository** level, not Environment level
2. Restart failed workflow runs (don't re-run jobs)
3. Check for typos in variable names

## 📚 **Summary**

This configuration system provides:
- **🎛️ Simple Control**: Repository-level variables for easy management
- **🔄 No Code Changes**: Enable/disable without modifying workflows
- **🚀 Fast Response**: Immediate effect on new workflow runs
- **🛡️ Safe Defaults**: Scans enabled by default for security
- **📊 Clear Logging**: Visible skip/enable messages in workflow logs

Use these variables responsibly to maintain security while providing operational flexibility! 🚀
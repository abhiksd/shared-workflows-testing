# JAR Artifact Upload/Download Troubleshooting Guide

## 📋 **Overview**

This guide helps troubleshoot JAR artifact upload and download issues in the Maven build and Docker build pipeline.

## 🔄 **Complete JAR Artifact Flow**

### **Step 1: Maven Build Action**
```yaml
# .github/actions/maven-build/action.yml
- name: Build application
  # Builds JAR file in target/ directory
  
- name: Upload build artifacts
  uses: actions/upload-artifact@v4
  with:
    name: ${{ inputs.application_name }}-jar  # e.g., "java-app-jar"
    path: |
      ${{ steps.build.outputs.jar_path }}    # e.g., "apps/java-app/target/app.jar"
      ${{ inputs.build_context }}/target/dependency-check-report.html
```

### **Step 2: Docker Build Action**
```yaml
# .github/actions/docker-build-push/action.yml
- name: Download JAR artifact
  if: inputs.application_type == 'java-springboot' && inputs.jar_artifact_name != ''
  uses: actions/download-artifact@v4
  with:
    name: ${{ inputs.jar_artifact_name }}     # e.g., "java-app-jar"
    path: ${{ inputs.build_context }}        # e.g., "apps/java-app"

- name: Verify build artifacts for Java applications
  # Verifies JAR files are present and valid
```

### **Step 3: Dockerfile**
```dockerfile
# Dockerfile uses the downloaded JAR
COPY *.jar app.jar
```

## 🔍 **Troubleshooting Common Issues**

### **Issue 1: "No JAR files found in build context"**

#### **Symptoms:**
```
❌ ERROR: No executable JAR files found in build context!
```

#### **Possible Causes & Solutions:**

**Cause 1: Maven build didn't create JAR**
```bash
# Check Maven build logs for errors
# Look for: [INFO] Building jar: target/app.jar
```
**Solution:** Fix Maven build issues (dependencies, compilation errors)

**Cause 2: JAR artifact upload failed**
```bash
# Check upload step in Maven build action
# Look for: ✅ JAR artifact uploaded: java-app-jar
```
**Solution:** Verify `upload_artifacts: 'true'` in Maven build call

**Cause 3: JAR artifact download failed**
```bash
# Check download step in Docker build action
# Look for artifact download step execution
```
**Solution:** Verify `jar_artifact_name` parameter is passed correctly

**Cause 4: Wrong build context path**
```bash
# JAR downloaded to wrong location
```
**Solution:** Verify `build_context` path matches between upload and download

### **Issue 2: Artifact not found**

#### **Symptoms:**
```
Error: Artifact 'java-app-jar' not found
```

#### **Solutions:**

**Check artifact name consistency:**
```yaml
# Maven build uploads as:
name: ${{ inputs.application_name }}-jar

# Docker build downloads as:
name: ${{ inputs.jar_artifact_name }}

# Workflow passes:
jar_artifact_name: ${{ needs.maven-build.outputs.jar_artifact }}
```

**Verify job dependencies:**
```yaml
# Docker build must depend on Maven build
docker-build:
  needs: [maven-build]  # Required!
```

### **Issue 3: JAR file corrupted or invalid**

#### **Symptoms:**
```
jar: invalid or corrupt jarfile
```

#### **Debugging Steps:**
```bash
# Check JAR file integrity
jar -tf app.jar | head -5

# Check JAR file size
ls -lh *.jar

# Verify JAR structure
unzip -l app.jar | grep -E "(BOOT-INF|META-INF)"
```

#### **Solutions:**
- Re-run Maven build with clean workspace
- Check for disk space issues during build
- Verify Maven configuration is correct

## 🛠️ **Enhanced Debugging**

### **Maven Build Action Debug**
```yaml
- name: Debug Maven Build
  run: |
    echo "🔍 Maven Build Debug Information:"
    echo "Working directory: $(pwd)"
    echo "Build context: ${{ inputs.build_context }}"
    echo "Application name: ${{ inputs.application_name }}"
    
    cd "${{ inputs.build_context }}"
    echo "Contents of target directory:"
    ls -la target/ || echo "No target directory found"
    
    echo "All JAR files in project:"
    find . -name "*.jar" -type f
    
    echo "Maven project version:"
    mvn help:evaluate -Dexpression=project.version -q -DforceStdout
```

### **Docker Build Action Debug**
```yaml
- name: Debug Docker Build Context
  run: |
    echo "🔍 Docker Build Context Debug:"
    echo "Build context: ${{ inputs.build_context }}"
    echo "JAR artifact name: ${{ inputs.jar_artifact_name }}"
    
    cd "${{ inputs.build_context }}"
    echo "Current directory: $(pwd)"
    echo "Directory contents:"
    ls -la
    
    echo "JAR files found:"
    find . -name "*.jar" -type f -exec ls -lh {} \;
    
    echo "Checking for Spring Boot JAR structure:"
    find . -name "*.jar" -type f | head -1 | xargs jar -tf | grep -E "BOOT-INF|org/springframework" | head -5
```

## 📋 **Verification Checklist**

### **Maven Build Verification:**
- [ ] Maven build completes successfully
- [ ] JAR file is created in target/ directory
- [ ] JAR file is executable (`java -jar app.jar --help`)
- [ ] Artifact upload step executes
- [ ] Artifact name is set correctly in outputs

### **Docker Build Verification:**
- [ ] Docker build job depends on Maven build job
- [ ] JAR artifact name is passed to Docker build action
- [ ] Artifact download step executes
- [ ] JAR file is present in build context
- [ ] JAR file verification passes
- [ ] Dockerfile can find and copy JAR file

### **Workflow Configuration:**
- [ ] `upload_artifacts: 'true'` in Maven build call
- [ ] `jar_artifact_name` parameter passed to Docker build
- [ ] Job dependencies are correct
- [ ] Build context paths are consistent

## 🔧 **Quick Fixes**

### **Fix 1: Ensure Artifact Upload**
```yaml
# In workflow that calls maven-build
- name: Maven Build
  uses: ./.github/actions/maven-build
  with:
    upload_artifacts: 'true'  # Must be true!
```

### **Fix 2: Add Missing JAR Artifact Parameter**
```yaml
# In workflow that calls docker-build-push
- name: Docker Build
  uses: ./.github/actions/docker-build-push
  with:
    jar_artifact_name: ${{ needs.maven-build.outputs.jar_artifact }}  # Add this!
```

### **Fix 3: Manual Artifact Download (Fallback)**
```yaml
# In workflow before docker-build-push
- name: Download Maven build artifacts
  if: inputs.application_type == 'java-springboot'
  uses: actions/download-artifact@v4
  with:
    name: ${{ needs.maven-build.outputs.jar_artifact }}
    path: ${{ inputs.build_context }}
```

### **Fix 4: Verify Maven Output**
```yaml
# Add to Maven build action
- name: Debug Maven Outputs
  run: |
    echo "JAR path: ${{ steps.build.outputs.jar_path }}"
    echo "Artifact name: ${{ steps.upload.outputs.artifact_name }}"
    echo "Build version: ${{ steps.version.outputs.build_version }}"
```

## 📊 **Monitoring and Validation**

### **GitHub Actions UI Checks:**
1. **Maven Build Job:** Look for ✅ "Upload build artifacts" step
2. **Docker Build Job:** Look for ✅ "Download JAR artifact" step  
3. **Artifacts Tab:** Verify artifact appears in workflow run artifacts
4. **Job Summary:** Check Maven build summary for artifact details

### **Log Patterns to Look For:**
```bash
# Successful patterns:
✅ JAR artifact uploaded: java-app-jar
✅ Found 1 executable JAR file(s) for Docker build
✅ JAR appears to be valid

# Error patterns:
❌ ERROR: No executable JAR files found
❌ Artifact 'java-app-jar' not found
⚠️ JAR verification failed
```

## 🎯 **Best Practices**

1. **✅ Always use consistent naming:** `${{ inputs.application_name }}-jar`
2. **✅ Set proper job dependencies:** Docker build needs Maven build
3. **✅ Enable artifact upload:** `upload_artifacts: 'true'`
4. **✅ Pass artifact name:** Use `jar_artifact_name` parameter
5. **✅ Verify in both places:** Maven upload AND Docker download
6. **✅ Use build summaries:** Monitor artifact status in job summaries

This ensures reliable JAR artifact flow from Maven build to Docker build! 🚀
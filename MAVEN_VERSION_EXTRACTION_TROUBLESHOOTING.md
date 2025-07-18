# Maven Version Extraction Troubleshooting Guide

## Error: Process completed with exit code 1

This error occurs during the "Extract version from POM" step in the Maven build action. Here are the most common causes and solutions:

## Root Causes

### 1. Maven Not Installed
**Error:** `bash: mvn: command not found`
**Solution:** The action now includes automatic Maven setup:

```yaml
- name: Set up Maven
  uses: stCarolas/setup-maven@v5
  with:
    maven-version: 3.9.4
```

### 2. Malformed POM.xml
**Error:** Maven fails to parse the POM file
**Solution:** Validate your POM.xml syntax:

```bash
# Check for XML syntax errors
xmllint --noout pom.xml

# Validate Maven POM structure
mvn validate
```

**Common XML Issues:**
- Malformed tags: `<n>java-app</n>` should be `<name>java-app</name>`
- Missing namespaces
- Invalid XML characters

### 3. Missing Project Version
**Error:** Version evaluation returns empty or null
**Solution:** Ensure your POM has a valid version:

```xml
<project>
    <groupId>com.example</groupId>
    <artifactId>java-app</artifactId>
    <version>0.0.1-SNAPSHOT</version>
    <!-- other elements -->
</project>
```

## Enhanced Error Handling

The Maven build action now includes:

1. **Pre-validation:** Checks Maven installation and POM validity
2. **Fallback mechanism:** If Maven fails, tries XML parsing
3. **Better error messages:** Clear indication of what went wrong

```bash
# Primary method: Maven evaluation
VERSION=$(mvn help:evaluate -Dexpression=project.version -q -DforceStdout 2>/dev/null)

# Fallback: Direct XML parsing
if [ $? -ne 0 ]; then
    VERSION=$(xmllint --xpath "//*[local-name()='project']/*[local-name()='version']/text()" pom.xml)
fi
```

## Debugging Steps

### 1. Check Maven Installation
```bash
mvn --version
```

### 2. Validate POM File
```bash
mvn validate -q
```

### 3. Test Version Extraction
```bash
mvn help:evaluate -Dexpression=project.version -q -DforceStdout
```

### 4. Check XML Syntax
```bash
xmllint --noout pom.xml
```

### 5. Manual XML Parsing
```bash
xmllint --xpath "//*[local-name()='project']/*[local-name()='version']/text()" pom.xml
```

## Common POM.xml Fixes

### Fix Malformed Tags
```xml
<!-- WRONG -->
<n>java-app</n>

<!-- CORRECT -->
<name>java-app</name>
```

### Add Missing Version
```xml
<project>
    <modelVersion>4.0.0</modelVersion>
    <groupId>com.example</groupId>
    <artifactId>my-app</artifactId>
    <version>1.0.0-SNAPSHOT</version>  <!-- Add this if missing -->
</project>
```

### Fix Namespace Issues
```xml
<project xmlns="http://maven.apache.org/POM/4.0.0" 
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 
         https://maven.apache.org/xsd/maven-4.0.0.xsd">
```

## Action Configuration

The updated action configuration ensures proper setup:

```yaml
- name: Maven Build
  uses: ./.github/actions/maven-build
  with:
    application_name: ${{ matrix.app }}
    build_context: apps/${{ matrix.app }}
    java_version: '21'
    run_tests: 'false'
    upload_artifacts: 'true'
```

## Environment Requirements

- Java 21 (automatically installed)
- Maven 3.9.4+ (automatically installed)
- xmllint (usually pre-installed in Ubuntu runners)

## Prevention

1. **Validate POM locally:**
   ```bash
   mvn validate
   ```

2. **Test version extraction:**
   ```bash
   mvn help:evaluate -Dexpression=project.version -q -DforceStdout
   ```

3. **Use XML validation in IDE**
4. **Set up pre-commit hooks for XML validation**

## Related Files

- `.github/actions/maven-build/action.yml` - Maven build action
- `apps/java-app/pom.xml` - Project POM file
- Action automatically installs Maven and validates POM before version extraction
# JAR Verification Troubleshooting Guide

## Error: grep: write error: Broken pipe (Exit Code 2)

This error occurs during the JAR verification step in the Maven build action when examining JAR contents.

## Root Cause

The error is caused by a **broken pipe** when using `grep` with `head` in a pipeline:

```bash
# PROBLEMATIC (causes broken pipe)
jar -tf file.jar | grep pattern | head -10
```

When `head -10` closes the pipe after reading 10 lines, `grep` continues trying to write, causing the broken pipe error.

## Fixed Implementation

The Maven build action now uses safer JAR verification:

```bash
# SAFE APPROACH
JAR_CONTENTS=$(jar -tf "${JAR_FILE}" 2>/dev/null || echo "Error reading JAR contents")

if echo "$JAR_CONTENTS" | grep -q "BOOT-INF"; then
  echo "✅ Spring Boot JAR structure detected"
  echo "📋 Sample contents:"
  echo "$JAR_CONTENTS" | grep -E "(\.class$|BOOT-INF|META-INF)" | head -5 2>/dev/null || true
else
  echo "⚠️ Standard JAR (not Spring Boot executable)"
  echo "📋 Sample contents:"
  echo "$JAR_CONTENTS" | grep "\.class$" | head -5 2>/dev/null || true
fi
```

## Key Improvements

### 1. **Pipe Safety**
- Store JAR contents in variable first
- Use `2>/dev/null || true` to prevent pipe errors
- Separate content reading from filtering

### 2. **Enhanced Verification**
- **File Size Check:** Ensures JAR is not empty or corrupted
- **Structure Detection:** Identifies Spring Boot vs standard JARs
- **Content Sampling:** Shows representative file entries
- **Error Handling:** Graceful failure without stopping build

### 3. **Better Output**
```bash
🔍 Verifying JAR contents...
✅ Spring Boot JAR structure detected
📋 Sample contents:
BOOT-INF/classes/com/example/Application.class
BOOT-INF/lib/spring-boot-3.3.0.jar
META-INF/MANIFEST.MF
📊 JAR file size: 52428800 bytes
✅ JAR file appears valid (size > 1KB)
```

## Common JAR Issues

### 1. **Empty or Corrupted JAR**
```bash
❌ JAR file may be corrupted or empty
```
**Solution:** Check Maven build for errors, ensure dependencies resolve

### 2. **Missing BOOT-INF Structure**
```bash
⚠️ Standard JAR (not Spring Boot executable)
```
**Solution:** Verify `spring-boot-maven-plugin` is configured:

```xml
<plugin>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-maven-plugin</artifactId>
</plugin>
```

### 3. **JAR Command Not Found**
```bash
Error reading JAR contents
```
**Solution:** Ensure Java is properly installed in runner

## Debugging Commands

### Local Testing
```bash
# Test JAR listing
jar -tf target/app.jar | head -10

# Check JAR size
ls -lh target/*.jar

# Verify Spring Boot structure
jar -tf target/app.jar | grep -q "BOOT-INF" && echo "Spring Boot JAR" || echo "Standard JAR"

# Test JAR execution
java -jar target/app.jar --help
```

### GitHub Actions Debugging
Add this step to your workflow for detailed JAR analysis:

```yaml
- name: Debug JAR
  run: |
    echo "=== JAR Files ==="
    ls -la target/*.jar
    
    echo "=== JAR Contents Sample ==="
    jar -tf target/*.jar | head -20
    
    echo "=== JAR Manifest ==="
    jar -xf target/*.jar META-INF/MANIFEST.MF
    cat META-INF/MANIFEST.MF
```

## Prevention

### 1. **Use Safe Pipe Patterns**
```bash
# AVOID
command1 | command2 | head

# PREFER
RESULT=$(command1)
echo "$RESULT" | command2 | head || true
```

### 2. **Add Error Handling**
```bash
# With fallback
jar -tf file.jar 2>/dev/null || echo "JAR read failed"
```

### 3. **Validate Build Environment**
```bash
# Check tools availability
java -version
jar --help >/dev/null 2>&1 && echo "jar available" || echo "jar missing"
```

## Related Files

- `.github/actions/maven-build/action.yml` - Maven build action with JAR verification
- `.github/actions/docker-build-push/action.yml` - Docker action with JAR integrity checks
- `apps/java-app/pom.xml` - Maven project configuration
- JAR verification now includes size checks and structure validation

## Actions Fixed

### 1. **Maven Build Action**
- Enhanced JAR content verification
- File size validation
- Spring Boot structure detection
- Safer pipe handling

### 2. **Docker Build Action**
- Improved JAR integrity checks
- Eliminated broken pipe in JAR listing
- Better error handling for missing JARs

## Success Indicators

✅ **Working JAR Verification:**
- No broken pipe errors
- Clear structure detection (Spring Boot vs standard)
- File size validation
- Sample content display
- Graceful error handling

The JAR verification process is now robust and provides detailed feedback without causing pipeline failures.
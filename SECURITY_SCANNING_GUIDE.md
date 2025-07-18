# 🔒 Security Scanning Configuration Guide

## ✅ **COMPREHENSIVE SECURITY SCANNING SYSTEM**

This guide documents the complete security scanning setup with SonarQube and Checkmarx integration, including configurable thresholds and PR merge requirements.

## 🎯 **SECURITY TOOLS INTEGRATED**

### **Primary Security Scanners**
- **SonarQube**: Code quality, coverage, and security analysis
- **Checkmarx SAST**: Static Application Security Testing
- **Checkmarx SCA**: Software Composition Analysis
- **Checkmarx KICS**: Infrastructure as Code Security

### **Architecture**
- **Simplified Design**: Direct integration of SonarQube and Checkmarx composite actions
- **Parallel Execution**: SonarQube and Checkmarx scans run in parallel for faster pipeline execution
- **Independent Control**: Each scanner can be enabled/disabled independently

### **Deployment Integration**
- **PR Security Checks**: Mandatory security scans before merge
- **Deployment Gating**: Both SonarQube and Checkmarx scans must pass before deployment
- **Configurable Thresholds**: Customizable security requirements per environment

## 🔧 **CONFIGURATION VARIABLES**

### **Repository Variables (GitHub Settings → Variables)**

#### **SonarQube Configuration**
```yaml
# Core SonarQube Settings
SONAR_ENABLED: 'true'                    # Enable/disable SonarQube scanning
SONAR_HOST_URL: 'https://sonar.company.com'  # SonarQube server URL
SONAR_PROJECT_KEY: 'my-project'          # Override default project key

# Quality Thresholds (Deployment)
SONAR_COVERAGE_THRESHOLD: '80'           # Minimum code coverage %
SONAR_RELIABILITY_RATING: '1'           # Max reliability rating (A=1, B=2, C=3, D=4, E=5)
SONAR_SECURITY_RATING: '1'              # Max security rating (A=1, B=2, C=3, D=4, E=5)
SONAR_MAINTAINABILITY_RATING: '2'       # Max maintainability rating

# PR-Specific Thresholds (Stricter)
SONAR_PR_COVERAGE_THRESHOLD: '75'       # Minimum coverage for PRs
SONAR_PR_RELIABILITY_RATING: '1'        # Max reliability rating for PRs
SONAR_PR_SECURITY_RATING: '1'           # Max security rating for PRs
SONAR_PR_MAINTAINABILITY_RATING: '2'    # Max maintainability rating for PRs
```

#### **Checkmarx Configuration**
```yaml
# Core Checkmarx Settings
CHECKMARX_ENABLED: 'true'                        # Enable/disable Checkmarx scanning
CHECKMARX_URL: 'https://checkmarx.company.com'   # Checkmarx server URL
CX_TENANT: 'company-tenant'                      # Checkmarx tenant for OAuth2 authentication

# Scan Configuration
CHECKMARX_SCAN_TYPES: 'sca,sast,kics'           # Scan types (comma-separated)
CHECKMARX_SAST_PRESET: 'Checkmarx Default'      # SAST preset to use
CHECKMARX_SCA_RESOLVER: 'auto'                  # SCA resolver type
CHECKMARX_KICS_PLATFORMS: 'Docker,Kubernetes,Terraform'  # KICS platforms

# Deployment Thresholds
CHECKMARX_FAIL_BUILD: 'true'                    # Fail build on security issues
CHECKMARX_HIGH_THRESHOLD: '0'                   # Max high severity issues
CHECKMARX_MEDIUM_THRESHOLD: '5'                 # Max medium severity issues
CHECKMARX_LOW_THRESHOLD: '10'                   # Max low severity issues

# PR-Specific Thresholds (Stricter)
CHECKMARX_PR_SCAN_TYPES: 'sast,sca'            # Scan types for PRs (faster)
CHECKMARX_PR_HIGH_THRESHOLD: '0'               # Max high severity for PRs
CHECKMARX_PR_MEDIUM_THRESHOLD: '3'             # Max medium severity for PRs
CHECKMARX_PR_LOW_THRESHOLD: '10'               # Max low severity for PRs
```

#### **Additional Security Tools**
```yaml
# OWASP Dependency Check
DEPENDENCY_CHECK_ENABLED: 'true'                # Enable OWASP dependency check

# Secret Scanning
SECRET_SCAN_ENABLED: 'true'                     # Enable secret detection
```

### **Repository Secrets (GitHub Settings → Secrets)**

#### **SonarQube Secrets**
```yaml
SONAR_TOKEN: 'squ_1234567890abcdef'             # SonarQube authentication token
```

#### **Checkmarx Secrets**
```yaml
CX_TENANT: 'company-tenant'                     # Checkmarx tenant for OAuth2 authentication
CHECKMARX_CLIENT_ID: 'client-id-123'            # Checkmarx OAuth2 client ID
CHECKMARX_CLIENT_SECRET: 'client-secret-123'    # Checkmarx OAuth2 client secret
```

## 📊 **SECURITY SCAN TYPES EXPLAINED**

### **SonarQube Analysis**
**Purpose**: Code quality, test coverage, and security vulnerability detection

**Java Spring Boot**:
- Uses Maven SonarQube plugin
- Analyzes compiled classes and test results
- Generates JaCoCo coverage reports
- Checks security hotspots and vulnerabilities

**Node.js**:
- Uses SonarScanner CLI
- Analyzes JavaScript/TypeScript source code
- Processes LCOV coverage reports
- Detects code smells and security issues

### **Checkmarx SAST (Static Application Security Testing)**
**Purpose**: Source code security analysis

**Scan Features**:
- Identifies security vulnerabilities in source code
- Detects SQL injection, XSS, CSRF vulnerabilities
- Analyzes data flow and control flow
- Provides detailed remediation guidance

**Configuration**:
```yaml
checkmarx_scan_types: 'sast'
checkmarx_sast_preset: 'Checkmarx Default'  # or 'High and Medium', 'All'
```

### **Checkmarx SCA (Software Composition Analysis)**
**Purpose**: Third-party dependency vulnerability scanning

**Scan Features**:
- Scans package manifests (pom.xml, package.json)
- Identifies known vulnerabilities in dependencies
- Provides license compliance information
- Suggests version updates and patches

**Configuration**:
```yaml
checkmarx_scan_types: 'sca'
checkmarx_sca_resolver: 'auto'  # or 'maven', 'npm', 'gradle'
```

### **Checkmarx KICS (Infrastructure as Code Security)**
**Purpose**: Infrastructure and configuration security

**Scan Features**:
- Analyzes Dockerfile security issues
- Scans Kubernetes manifests for misconfigurations
- Checks Terraform/CloudFormation templates
- Identifies cloud security misconfigurations

**Configuration**:
```yaml
checkmarx_scan_types: 'kics'
checkmarx_kics_platforms: 'Docker,Kubernetes,Terraform'
```

### **OWASP Dependency Check**
**Purpose**: Additional vulnerability scanning

**Features**:
- Cross-references with CVE database
- Analyzes JAR files and Node modules
- Provides CVSS scoring
- Generates detailed HTML reports

### **TruffleHog Secret Scanning**
**Purpose**: Credential and secret detection

**Features**:
- Scans for hardcoded secrets
- Detects API keys, passwords, tokens
- Uses entropy analysis and regex patterns
- Prevents credential leaks

## 🚀 **USAGE EXAMPLES**

### **Basic Configuration (Recommended)**
```yaml
# Enable all security tools with moderate thresholds
SONAR_ENABLED: 'true'
SONAR_COVERAGE_THRESHOLD: '75'
CHECKMARX_ENABLED: 'true'
CHECKMARX_SCAN_TYPES: 'sca,sast'
CHECKMARX_HIGH_THRESHOLD: '0'
CHECKMARX_MEDIUM_THRESHOLD: '5'
DEPENDENCY_CHECK_ENABLED: 'true'
SECRET_SCAN_ENABLED: 'true'
```

### **Strict Security (Enterprise)**
```yaml
# Maximum security with strict thresholds
SONAR_COVERAGE_THRESHOLD: '85'
SONAR_RELIABILITY_RATING: '1'
SONAR_SECURITY_RATING: '1'
CHECKMARX_SCAN_TYPES: 'sca,sast,kics'
CHECKMARX_HIGH_THRESHOLD: '0'
CHECKMARX_MEDIUM_THRESHOLD: '2'
CHECKMARX_LOW_THRESHOLD: '5'
```

### **Development-Friendly (Fast Feedback)**
```yaml
# Faster scans for development environments
CHECKMARX_SCAN_TYPES: 'sca'
CHECKMARX_PR_SCAN_TYPES: 'sast'
SONAR_PR_COVERAGE_THRESHOLD: '70'
CHECKMARX_PR_MEDIUM_THRESHOLD: '5'
```

### **Legacy System (Gradual Improvement)**
```yaml
# Relaxed thresholds for legacy applications
SONAR_COVERAGE_THRESHOLD: '60'
SONAR_RELIABILITY_RATING: '2'
CHECKMARX_HIGH_THRESHOLD: '1'
CHECKMARX_MEDIUM_THRESHOLD: '10'
CHECKMARX_LOW_THRESHOLD: '20'
```

## 📋 **WORKFLOW BEHAVIOR**

### **Pull Request Workflow**
1. **Change Detection**: Identifies modified applications
2. **Security Scanning**: Runs scans only for changed apps
3. **Threshold Validation**: Checks against PR-specific thresholds
4. **PR Comment**: Posts detailed security results
5. **Merge Blocking**: Prevents merge if security scans fail

### **Deployment Workflow**
1. **Security Gate**: Mandatory security scans before build
2. **Threshold Validation**: Checks against deployment thresholds
3. **Deployment Blocking**: Prevents deployment if scans fail
4. **Artifact Storage**: Saves security reports for audit

### **Scan Results Processing**

#### **SonarQube Results**
```bash
# Quality Gate Status: PASSED/FAILED
# Coverage: 85%
# Security Rating: A (1)
# Reliability Rating: A (1)
# Maintainability Rating: B (2)
```

#### **Checkmarx Results**
```bash
# SAST: H0/M2/L5 (High: 0, Medium: 2, Low: 5)
# SCA: H0/M1/L3
# KICS: H0/M0/L2
```

## 🔍 **TROUBLESHOOTING**

### **Common Issues**

#### **SonarQube Connection Issues**
```yaml
# Check configuration
SONAR_HOST_URL: 'https://sonar.company.com'  # Correct URL format
SONAR_TOKEN: 'squ_***'                       # Valid token with project permissions
```

#### **Checkmarx Authentication Issues**
```yaml
# For OAuth2 client credentials authentication
CX_TENANT: 'correct-tenant-name'
CHECKMARX_CLIENT_ID: 'correct-client-id'
CHECKMARX_CLIENT_SECRET: 'correct-client-secret'
```

#### **Threshold Failures**
```bash
# Coverage below threshold
❌ Coverage 70% is below threshold 80%
# Solution: Increase test coverage or adjust threshold

# Security issues exceed threshold
❌ SAST: High severity issues (2) exceed threshold (0)
# Solution: Fix security issues or adjust threshold (not recommended)
```

### **Disabling Specific Scans**

#### **Disable SonarQube for Specific Application**
```yaml
# In PR workflow - add condition
sonar_enabled: ${{ vars.SONAR_ENABLED && inputs.application_name != 'legacy-app' }}
```

#### **Skip Checkmarx KICS for Node.js**
```yaml
# Use different scan types per application
checkmarx_scan_types: ${{ inputs.application_type == 'nodejs' && 'sca,sast' || 'sca,sast,kics' }}
```

#### **Temporary Threshold Override**
```yaml
# Use environment-specific variables
checkmarx_high_threshold: ${{ vars.EMERGENCY_HIGH_THRESHOLD || vars.CHECKMARX_HIGH_THRESHOLD || '0' }}
```

## 📈 **SECURITY METRICS & REPORTING**

### **Generated Reports**
- **SonarQube**: Web dashboard with detailed metrics
- **Checkmarx SAST**: XML/PDF reports with vulnerability details
- **Checkmarx SCA**: JSON reports with dependency vulnerabilities
- **KICS**: JSON/HTML reports with infrastructure issues
- **OWASP Dependency Check**: HTML reports with CVE details
- **Security Summary**: Markdown summary in PR comments

### **Artifact Storage**
All security scan results are automatically uploaded as GitHub artifacts:
- Retention: 30 days
- Accessible through GitHub Actions interface
- Available for audit and compliance purposes

## ✅ **VERIFICATION CHECKLIST**

### **Initial Setup** ✅
- [x] Repository variables configured
- [x] Repository secrets added
- [x] SonarQube server accessible
- [x] Checkmarx server accessible
- [x] Security thresholds defined

### **Pull Request Integration** ✅
- [x] PR security checks trigger on code changes
- [x] Security scan results posted as PR comments
- [x] Failed security scans block PR merge
- [x] Threshold violations clearly reported

### **Deployment Integration** ✅
- [x] Security scans run before deployment
- [x] Failed security scans block deployment
- [x] Security scan artifacts uploaded
- [x] Deployment proceeds only after security approval

## 🎯 **BEST PRACTICES**

### **Threshold Management**
1. **Start Conservative**: Begin with relaxed thresholds and gradually tighten
2. **Environment-Specific**: Use stricter thresholds for production
3. **Application-Specific**: Adjust thresholds based on application criticality
4. **Regular Review**: Periodically review and update thresholds

### **Scan Type Selection**
1. **PRs**: Use fast scans (SAST + SCA) for quick feedback
2. **Main Branch**: Include all scans (SAST + SCA + KICS) for comprehensive coverage
3. **Production**: Run full security suite including dependency checks

### **Performance Optimization**
1. **Parallel Scanning**: Multiple scan types run concurrently
2. **Incremental Analysis**: SonarQube analyzes only changed code
3. **Caching**: Maven/npm dependencies cached between runs
4. **Conditional Execution**: Scans only run when code changes

### **Security Culture**
1. **Clear Communication**: Detailed PR comments explain security issues
2. **Developer Education**: Link to remediation guides and best practices
3. **Gradual Improvement**: Focus on preventing new issues while fixing existing ones
4. **Compliance Ready**: Maintain audit trails with security scan artifacts

## 🚀 **READY FOR ENTERPRISE USE**

This security scanning system provides:

✅ **Comprehensive Coverage**: Multiple security tools for complete analysis  
✅ **Configurable Thresholds**: Flexible security requirements per environment  
✅ **PR Integration**: Automated security checks before merge  
✅ **Deployment Gating**: Security approval required for deployment  
✅ **Audit Compliance**: Complete security scan artifacts and reporting  
✅ **Developer Friendly**: Clear feedback and actionable security guidance  

**Zero security issues reach production without explicit approval!**
# Maven Build Troubleshooting Guide

## 🚨 **Spring Boot Dependency Injection Error**

### **Error Analysis:**
```
Error creating bean with name 'sldHelperService': 
Unsatisfied dependency expressed through constructor parameter 2: 
No qualifying bean of type 'com.schneider.dces.sldbackendcommons.services.sld.SldRuleService' available
```

### **Root Cause:**
The application `dces-sld-helper` is missing a required dependency bean `SldRuleService` from the `sldbackendcommons` library.

## 🔧 **Solutions**

### **1. Check Missing Dependencies in POM**

**Add the missing dependency to your `pom.xml`:**

```xml
<dependencies>
    <!-- Add the missing sldbackendcommons dependency -->
    <dependency>
        <groupId>com.schneider.dces</groupId>
        <artifactId>sldbackendcommons</artifactId>
        <version>YOUR_VERSION</version>
    </dependency>
    
    <!-- Ensure all Spring Boot starters are included -->
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-web</artifactId>
    </dependency>
    
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-data-mongodb</artifactId>
    </dependency>
    
    <!-- Add other required dependencies -->
</dependencies>
```

### **2. Verify Component Scanning**

**Ensure your main application class includes proper component scanning:**

```java
@SpringBootApplication
@ComponentScan(basePackages = {
    "com.schneider.dces.sldhelper",           // Your main package
    "com.schneider.dces.sldbackendcommons"   // External library package
})
@EnableMongoRepositories(basePackages = {
    "com.schneider.dces.sldhelper.repositories",
    "com.schneider.dces.sldbackendcommons.repositories"
})
public class SldHelperApplication {
    public static void main(String[] args) {
        SpringApplication.run(SldHelperApplication.class, args);
    }
}
```

### **3. Maven Build Verification**

**Run these commands to verify your build:**

```bash
# Clean and verify dependencies
mvn clean dependency:tree

# Check for missing dependencies
mvn dependency:analyze

# Compile and package
mvn clean compile package

# Run with verbose output
mvn clean package -X

# Test the JAR
java -jar target/dces-sld-helper-13.0.0-SNAPSHOT.jar --debug
```

### **4. Check Spring Boot Configuration**

**Add to `application.properties` or `application.yml`:**

```properties
# Enable debug logging
logging.level.org.springframework=DEBUG
logging.level.com.schneider.dces=DEBUG

# Spring Boot debug mode
debug=true

# Component scan logging
logging.level.org.springframework.context.annotation=TRACE
```

### **5. Dependency Resolution Issues**

**Check if the dependency is available:**

```bash
# Search for the missing artifact
mvn dependency:resolve -Dverbose

# Check repository connectivity
mvn dependency:resolve-sources

# Verify artifact exists in repository
mvn help:evaluate -Dexpression=project.dependencyManagement -q
```

## 🔍 **Maven vs Maven Wrapper Differences**

### **Potential Issues When Switching from mvnw to mvn:**

#### **1. Maven Version Differences**
```bash
# Check Maven version
mvn --version

# Maven wrapper was pinned to specific version
# Standard Maven uses system-installed version
```

#### **2. Repository Configuration**
```bash
# Check Maven settings
mvn help:effective-settings

# Verify repository access
mvn dependency:resolve -U
```

#### **3. Build Environment**
```bash
# Check Java version compatibility
java --version
mvn --version

# Verify JAVA_HOME
echo $JAVA_HOME
```

## 🛠️ **Specific Fixes for Your Application**

### **Fix 1: Add Missing Dependency**

**Update your `pom.xml`:**

```xml
<dependencies>
    <!-- Add this missing dependency -->
    <dependency>
        <groupId>com.schneider.dces</groupId>
        <artifactId>sld-backend-commons</artifactId>
        <version>${sld.backend.commons.version}</version>
    </dependency>
    
    <!-- Spring Boot MongoDB -->
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-data-mongodb</artifactId>
    </dependency>
    
    <!-- Other dependencies as needed -->
</dependencies>

<properties>
    <sld.backend.commons.version>1.0.0</sld.backend.commons.version>
</properties>
```

### **Fix 2: Create Mock Bean (Temporary)**

**If dependency is not available, create a mock:**

```java
@TestConfiguration
public class TestConfig {
    
    @Bean
    @Primary
    public SldRuleService mockSldRuleService() {
        return Mockito.mock(SldRuleService.class);
    }
}
```

### **Fix 3: Conditional Bean Creation**

**Make the bean optional:**

```java
@Service
public class SldHelperService {
    
    private final SldRuleService sldRuleService;
    
    public SldHelperService(
            // Other parameters
            @Autowired(required = false) SldRuleService sldRuleService) {
        this.sldRuleService = sldRuleService;
    }
    
    // Handle null case in methods
    public void someMethod() {
        if (sldRuleService != null) {
            sldRuleService.doSomething();
        } else {
            // Fallback behavior
        }
    }
}
```

## 🧪 **Testing the Fix**

### **1. Verify Dependencies**
```bash
# Check if all dependencies are resolved
mvn dependency:tree | grep sldbackendcommons

# Verify the specific class exists
jar -tf target/dces-sld-helper-13.0.0-SNAPSHOT.jar | grep SldRuleService
```

### **2. Test Build Process**
```bash
# Clean build
mvn clean package

# Run with debug
java -jar target/dces-sld-helper-13.0.0-SNAPSHOT.jar --debug

# Check application context
java -jar target/dces-sld-helper-13.0.0-SNAPSHOT.jar --spring.output.ansi.enabled=always
```

### **3. Verify Spring Context**
```java
// Add this to your main class for debugging
@SpringBootApplication
public class SldHelperApplication {
    
    public static void main(String[] args) {
        ConfigurableApplicationContext context = SpringApplication.run(SldHelperApplication.class, args);
        
        // Debug: Print all beans
        String[] beanNames = context.getBeanDefinitionNames();
        for (String beanName : beanNames) {
            if (beanName.contains("Sld")) {
                System.out.println("Bean: " + beanName + " -> " + context.getBean(beanName).getClass());
            }
        }
    }
}
```

## 🚀 **GitHub Actions Integration**

### **Update Maven Build Action for Better Debugging**

```yaml
# Add to .github/actions/maven-build/action.yml
- name: Debug Dependencies
  working-directory: ${{ inputs.build_context }}
  run: |
    echo "🔍 Checking Maven dependencies..."
    mvn dependency:tree
    mvn dependency:analyze
    
    echo "🔍 Checking for missing classes..."
    find target -name "*.jar" -exec jar -tf {} \; | grep -i sld || echo "No SLD classes found"
  shell: bash

- name: Enhanced Build with Debugging
  working-directory: ${{ inputs.build_context }}
  run: |
    echo "🏗️ Building with enhanced debugging..."
    mvn clean package -X | tee build.log
    
    # Check if specific classes are in the JAR
    jar -tf target/*.jar | grep -E "(SldRuleService|SldHelperService)" || echo "⚠️ SLD services not found in JAR"
    
    # Test JAR execution
    java -cp target/*.jar org.springframework.boot.loader.JarLauncher --help || echo "JAR execution test completed"
  shell: bash
```

## 📋 **Quick Checklist**

- [ ] **Dependencies:** All required dependencies in `pom.xml`
- [ ] **Component Scan:** Proper `@ComponentScan` configuration
- [ ] **Repository Access:** Maven can download dependencies
- [ ] **Java Version:** Compatible Java version
- [ ] **Maven Version:** Working Maven installation
- [ ] **Build Clean:** `mvn clean package` succeeds
- [ ] **JAR Contents:** Required classes present in JAR
- [ ] **Spring Context:** All beans can be created

## 🔧 **Emergency Quick Fix**

**If you need to get the application running immediately:**

```java
// Create a temporary configuration class
@Configuration
public class EmergencyConfig {
    
    @Bean
    @ConditionalOnMissingBean(SldRuleService.class)
    public SldRuleService temporarySldRuleService() {
        return new SldRuleService() {
            // Implement required methods with temporary logic
            @Override
            public void someMethod() {
                log.warn("Using temporary SldRuleService implementation");
                // Add temporary implementation
            }
        };
    }
}
```

This should resolve the dependency injection issue and get your application running! 🚀
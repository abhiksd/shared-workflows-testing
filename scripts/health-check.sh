#!/bin/bash

# Comprehensive Health Check Script for Microservices Deployment
# This script verifies all components after deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ENVIRONMENT=${1:-dev}
DOMAIN="${ENVIRONMENT}.mydomain.com"
TIMEOUT=30
VERBOSE=${2:-false}

# Health check counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

print_header() {
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${BLUE}  🚀 Microservices Health Check Tool${NC}"
    echo -e "${BLUE}  Environment: $ENVIRONMENT${NC}"
    echo -e "${BLUE}  Domain: $DOMAIN${NC}"
    echo -e "${BLUE}=================================================${NC}"
    echo ""
}

print_section() {
    echo -e "${BLUE}$1${NC}"
    echo "$(printf '=%.0s' {1..50})"
}

log_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${YELLOW}[VERBOSE] $1${NC}"
    fi
}

# Function to check URL and report status
check_url() {
    local url=$1
    local description=$2
    local expected_status=${3:-200}
    local check_type=${4:-GET}
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    log_verbose "Checking: $url"
    
    if [[ $check_type == "GET" ]]; then
        response=$(curl -s -w "%{http_code}:%{time_total}" -o /tmp/health_response --connect-timeout $TIMEOUT --max-time $TIMEOUT "$url" 2>/dev/null)
    else
        response=$(curl -s -I -w "%{http_code}:%{time_total}" --connect-timeout $TIMEOUT --max-time $TIMEOUT "$url" 2>/dev/null | tail -1)
    fi
    
    if [[ $? -eq 0 ]]; then
        status_code=$(echo "$response" | cut -d':' -f1)
        response_time=$(echo "$response" | cut -d':' -f2)
        
        if [[ $status_code -eq $expected_status ]]; then
            echo -e "✅ $description: ${GREEN}OK${NC} (${status_code}, ${response_time}s)"
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
            return 0
        else
            echo -e "❌ $description: ${RED}FAILED${NC} (${status_code}, ${response_time}s)"
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
            if [[ "$VERBOSE" == "true" && -f /tmp/health_response ]]; then
                echo -e "${YELLOW}Response body:${NC}"
                cat /tmp/health_response | head -5
            fi
            return 1
        fi
    else
        echo -e "❌ $description: ${RED}CONNECTION FAILED${NC}"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        return 1
    fi
}

# Function to check JSON response for specific fields
check_json_endpoint() {
    local url=$1
    local description=$2
    local field_check=$3
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    log_verbose "Checking JSON endpoint: $url"
    
    if response=$(curl -s --connect-timeout $TIMEOUT --max-time $TIMEOUT "$url" 2>/dev/null); then
        if echo "$response" | jq -e "$field_check" > /dev/null 2>&1; then
            echo -e "✅ $description: ${GREEN}OK${NC} (JSON valid)"
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
            if [[ "$VERBOSE" == "true" ]]; then
                echo -e "${YELLOW}Response:${NC} $(echo "$response" | jq -c '.')"
            fi
            return 0
        else
            echo -e "❌ $description: ${RED}INVALID JSON${NC}"
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
            if [[ "$VERBOSE" == "true" ]]; then
                echo -e "${YELLOW}Response:${NC} $response"
            fi
            return 1
        fi
    else
        echo -e "❌ $description: ${RED}CONNECTION FAILED${NC}"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        return 1
    fi
}

# Function to check Kubernetes resources
check_k8s_resource() {
    local resource_type=$1
    local resource_name=$2
    local namespace=${3:-default}
    local description=$4
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    log_verbose "Checking Kubernetes $resource_type: $resource_name in namespace $namespace"
    
    if kubectl get $resource_type $resource_name -n $namespace > /dev/null 2>&1; then
        status=$(kubectl get $resource_type $resource_name -n $namespace -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
        if [[ "$status" == "True" ]]; then
            echo -e "✅ $description: ${GREEN}READY${NC}"
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
            return 0
        else
            echo -e "⚠️  $description: ${YELLOW}NOT READY${NC}"
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
            return 1
        fi
    else
        echo -e "❌ $description: ${RED}NOT FOUND${NC}"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        return 1
    fi
}

# Main health check functions
check_backend_services() {
    print_section "🏗️ Backend Services Health Check"
    
    # Java Spring Boot Services
    echo -e "${YELLOW}Java Spring Boot Services:${NC}"
    check_url "https://$DOMAIN/backend1/actuator/health" "Java Backend 1 (User Management)"
    check_url "https://$DOMAIN/backend2/actuator/health" "Java Backend 2 (Product Catalog)"
    check_url "https://$DOMAIN/backend3/actuator/health" "Java Backend 3 (Order Management)"
    
    echo ""
    echo -e "${YELLOW}Node.js Express Services:${NC}"
    check_url "https://$DOMAIN/backend1/health" "Node.js Backend 1 (Notification)"
    check_url "https://$DOMAIN/backend2/health" "Node.js Backend 2 (Analytics)"
    check_url "https://$DOMAIN/backend3/health" "Node.js Backend 3 (File Management)"
    echo ""
}

check_api_endpoints() {
    print_section "🔗 API Endpoints Check"
    
    check_json_endpoint "https://$DOMAIN/backend1/api/status" "Java Backend 1 API Status" '.service'
    check_json_endpoint "https://$DOMAIN/backend2/api/status" "Java Backend 2 API Status" '.service'
    check_json_endpoint "https://$DOMAIN/backend3/api/status" "Java Backend 3 API Status" '.service'
    
    # Test API endpoints with sample requests
    check_url "https://$DOMAIN/backend1/api/users" "Java Backend 1 Users API"
    check_url "https://$DOMAIN/backend2/api/products" "Java Backend 2 Products API"
    check_url "https://$DOMAIN/backend3/api/orders" "Java Backend 3 Orders API"
    echo ""
}

check_monitoring_stack() {
    print_section "📊 Monitoring Stack Check"
    
    check_url "https://$DOMAIN/prometheus/-/healthy" "Prometheus Health"
    check_url "https://$DOMAIN/prometheus/-/ready" "Prometheus Ready"
    check_url "https://$DOMAIN/grafana/api/health" "Grafana Health"
    check_url "https://$DOMAIN/alertmanager/-/healthy" "AlertManager Health"
    
    # Check if Loki is accessible (if deployed)
    check_url "https://$DOMAIN/loki/ready" "Loki Ready" 200
    echo ""
}

check_metrics_endpoints() {
    print_section "📈 Metrics Endpoints Check"
    
    check_url "https://$DOMAIN/backend1/actuator/prometheus" "Java Backend 1 Metrics"
    check_url "https://$DOMAIN/backend2/actuator/prometheus" "Java Backend 2 Metrics"
    check_url "https://$DOMAIN/backend3/actuator/prometheus" "Java Backend 3 Metrics"
    
    check_url "https://$DOMAIN/backend1/metrics" "Node.js Backend 1 Metrics"
    check_url "https://$DOMAIN/backend2/metrics" "Node.js Backend 2 Metrics"
    check_url "https://$DOMAIN/backend3/metrics" "Node.js Backend 3 Metrics"
    echo ""
}

check_performance() {
    print_section "⚡ Performance Check"
    
    for service in backend1 backend2 backend3; do
        log_verbose "Testing response time for $service"
        start_time=$(date +%s.%N)
        if curl -s --connect-timeout $TIMEOUT --max-time $TIMEOUT "https://$DOMAIN/$service/actuator/health" > /dev/null 2>&1; then
            end_time=$(date +%s.%N)
            response_time=$(echo "$end_time - $start_time" | bc -l)
            
            if (( $(echo "$response_time < 2.0" | bc -l) )); then
                echo -e "✅ $service response time: ${GREEN}$(printf "%.3f" $response_time)s${NC}"
            elif (( $(echo "$response_time < 5.0" | bc -l) )); then
                echo -e "⚠️  $service response time: ${YELLOW}$(printf "%.3f" $response_time)s${NC} (acceptable)"
            else
                echo -e "❌ $service response time: ${RED}$(printf "%.3f" $response_time)s${NC} (slow)"
            fi
        else
            echo -e "❌ $service: ${RED}TIMEOUT${NC}"
        fi
    done
    echo ""
}

check_kubernetes_resources() {
    print_section "☸️  Kubernetes Resources Check"
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        echo -e "⚠️  kubectl not available, skipping Kubernetes checks"
        return
    fi
    
    # Check deployments
    echo -e "${YELLOW}Checking Deployments:${NC}"
    check_k8s_resource "deployment" "java-backend1" "default" "Java Backend 1 Deployment"
    check_k8s_resource "deployment" "java-backend2" "default" "Java Backend 2 Deployment"
    check_k8s_resource "deployment" "java-backend3" "default" "Java Backend 3 Deployment"
    check_k8s_resource "deployment" "nodejs-backend1" "default" "Node.js Backend 1 Deployment"
    check_k8s_resource "deployment" "nodejs-backend2" "default" "Node.js Backend 2 Deployment"
    check_k8s_resource "deployment" "nodejs-backend3" "default" "Node.js Backend 3 Deployment"
    
    # Check services
    echo ""
    echo -e "${YELLOW}Checking Services:${NC}"
    for backend in java-backend1 java-backend2 java-backend3 nodejs-backend1 nodejs-backend2 nodejs-backend3; do
        if kubectl get service $backend -n default > /dev/null 2>&1; then
            echo -e "✅ Service $backend: ${GREEN}EXISTS${NC}"
        else
            echo -e "❌ Service $backend: ${RED}NOT FOUND${NC}"
        fi
    done
    echo ""
}

check_ssl_certificates() {
    print_section "🔐 SSL Certificate Check"
    
    for env_domain in dev.mydomain.com staging.mydomain.com production.mydomain.com; do
        log_verbose "Checking SSL certificate for $env_domain"
        
        # Get certificate expiration
        if cert_info=$(echo | openssl s_client -servername $env_domain -connect $env_domain:443 2>/dev/null | openssl x509 -noout -dates 2>/dev/null); then
            expiry_date=$(echo "$cert_info" | grep "notAfter" | cut -d= -f2)
            expiry_timestamp=$(date -d "$expiry_date" +%s 2>/dev/null || date -j -f "%b %d %H:%M:%S %Y %Z" "$expiry_date" +%s 2>/dev/null)
            current_timestamp=$(date +%s)
            days_until_expiry=$(( (expiry_timestamp - current_timestamp) / 86400 ))
            
            if [[ $days_until_expiry -gt 30 ]]; then
                echo -e "✅ $env_domain SSL: ${GREEN}Valid${NC} (expires in $days_until_expiry days)"
            elif [[ $days_until_expiry -gt 7 ]]; then
                echo -e "⚠️  $env_domain SSL: ${YELLOW}Valid${NC} (expires in $days_until_expiry days - renew soon)"
            else
                echo -e "❌ $env_domain SSL: ${RED}Expiring soon${NC} (expires in $days_until_expiry days)"
            fi
        else
            echo -e "❌ $env_domain SSL: ${RED}Cannot verify${NC}"
        fi
    done
    echo ""
}

print_summary() {
    print_section "📊 Health Check Summary"
    
    echo -e "Total Checks: ${BLUE}$TOTAL_CHECKS${NC}"
    echo -e "Passed: ${GREEN}$PASSED_CHECKS${NC}"
    echo -e "Failed: ${RED}$FAILED_CHECKS${NC}"
    
    success_rate=$(( PASSED_CHECKS * 100 / TOTAL_CHECKS ))
    echo -e "Success Rate: ${BLUE}$success_rate%${NC}"
    
    echo ""
    if [[ $FAILED_CHECKS -eq 0 ]]; then
        echo -e "${GREEN}🎉 All checks passed! System is healthy.${NC}"
        exit 0
    elif [[ $success_rate -ge 80 ]]; then
        echo -e "${YELLOW}⚠️  Most checks passed, but some issues detected.${NC}"
        exit 1
    else
        echo -e "${RED}❌ Multiple failures detected. System needs attention.${NC}"
        exit 2
    fi
}

show_help() {
    echo "Microservices Health Check Script"
    echo ""
    echo "Usage: $0 [ENVIRONMENT] [VERBOSE]"
    echo ""
    echo "Arguments:"
    echo "  ENVIRONMENT    Target environment (dev, staging, production). Default: dev"
    echo "  VERBOSE        Enable verbose output (true/false). Default: false"
    echo ""
    echo "Examples:"
    echo "  $0                    # Check dev environment"
    echo "  $0 staging            # Check staging environment"
    echo "  $0 production true    # Check production with verbose output"
    echo ""
    echo "Exit codes:"
    echo "  0 - All checks passed"
    echo "  1 - Some checks failed (>= 80% success rate)"
    echo "  2 - Many checks failed (< 80% success rate)"
}

# Main execution
main() {
    if [[ "$1" == "--help" || "$1" == "-h" ]]; then
        show_help
        exit 0
    fi
    
    # Check dependencies
    if ! command -v curl &> /dev/null; then
        echo -e "${RED}Error: curl is required but not installed.${NC}"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        echo -e "${YELLOW}Warning: jq not found. JSON checks will be skipped.${NC}"
    fi
    
    if ! command -v bc &> /dev/null; then
        echo -e "${YELLOW}Warning: bc not found. Some calculations may be skipped.${NC}"
    fi
    
    print_header
    
    # Run all health checks
    check_backend_services
    check_api_endpoints
    check_monitoring_stack
    check_metrics_endpoints
    check_performance
    check_kubernetes_resources
    check_ssl_certificates
    
    print_summary
}

# Cleanup function
cleanup() {
    rm -f /tmp/health_response
}

# Set up cleanup
trap cleanup EXIT

# Run main function with all arguments
main "$@"
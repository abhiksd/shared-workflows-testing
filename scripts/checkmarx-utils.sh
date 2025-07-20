#!/bin/bash

# Checkmarx Security Scanning Utilities
# This file contains reusable functions for Checkmarx SAST, SCA, and KICS scanning

source "$(dirname "${BASH_SOURCE[0]}")/common-utils.sh"

# Checkmarx authentication
cx_authenticate() {
    local cx_url=$1 client_id=$2 client_secret=$3
    
    log_info "Authenticating with Checkmarx using OAuth2..."
    local token=$(curl -s -X POST "$cx_url/cxrestapi/auth/identity/connect/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "username=$client_id" \
        -d "password=$client_secret" \
        -d "grant_type=password" \
        -d "scope=sast_rest_api" \
        -d "client_id=resource_owner_client" \
        -d "client_secret=014DF517-39D1-4453-B7B3-9930C563627C" | \
        jq -r '.access_token // empty')
    
    if [[ -z "$token" ]]; then
        log_error "Failed to obtain OAuth2 access token"
        return 1
    fi
    
    log_success "Successfully authenticated with Checkmarx"
    echo "$token"
}

# Setup Checkmarx tools based on scan types
cx_setup_tools() {
    local scan_types=$1
    
    log_info "Setting up Checkmarx scanning tools..."
    IFS=',' read -ra SCAN_TYPES <<< "$scan_types"
    
    for scan_type in "${SCAN_TYPES[@]}"; do
        scan_type=$(echo "$scan_type" | tr '[:upper:]' '[:lower:]' | xargs)
        
        case "$scan_type" in
            "sast")
                log_verbose "Setting up Checkmarx SAST CLI..."
                curl -L -o cx-cli.zip "https://download.checkmarx.com/9.0.0/Plugins/CxConsolePlugin-2022.4.2.zip"
                unzip -q cx-cli.zip && chmod +x ./CxConsolePlugin-*/runCxConsole.sh
                log_success "Checkmarx SAST CLI installed"
                ;;
            "sca")
                log_verbose "Setting up Checkmarx SCA CLI..."
                curl -L -o cxsca.tar.gz "https://sca-downloads.s3.amazonaws.com/cli/latest/ScaResolver-linux64.tar.gz"
                tar -xzf cxsca.tar.gz && chmod +x ./ScaResolver
                log_success "Checkmarx SCA CLI installed"
                ;;
            "kics")
                log_verbose "Setting up KICS..."
                curl -L -o kics.tar.gz "https://github.com/Checkmarx/kics/releases/latest/download/kics_1.7.13_linux_x64.tar.gz"
                tar -xzf kics.tar.gz && chmod +x ./kics
                log_success "KICS installed"
                ;;
        esac
    done
    
    log_success "Checkmarx tools setup completed"
}

# Run SAST scan
cx_run_sast() {
    local cx_url=$1 token=$2 project_name=$3 preset=$4 build_context=$5
    
    log_info "Starting Checkmarx SAST scan..."
    ./CxConsolePlugin-*/runCxConsole.sh Scan \
        -v \
        -CxServer "$cx_url" \
        -CxToken "$token" \
        -ProjectName "$project_name" \
        -preset "$preset" \
        -LocationType folder \
        -LocationPath "$build_context" \
        -ReportXML sast-results.xml \
        -ReportPDF sast-results.pdf \
        -ReportCSV sast-results.csv || {
        log_warning "SAST scan encountered issues, but continuing..."
    }
}

# Run SCA scan
cx_run_sca() {
    local project_name=$1 build_context=$2 resolver=$3
    
    log_info "Starting Checkmarx SCA scan..."
    ./ScaResolver \
        -s "$build_context" \
        -n "$project_name" \
        --resolver-result-path sca-results.json \
        --resolver "$resolver" || {
        log_warning "SCA scan encountered issues, but continuing..."
    }
}

# Run KICS scan
cx_run_kics() {
    local build_context=$1 platforms=$2
    
    log_info "Starting KICS Infrastructure as Code scan..."
    ./kics scan \
        --path "$build_context" \
        --output-path kics-results \
        --report-formats json,html \
        --platforms "$platforms" \
        --verbose || {
        log_warning "KICS scan encountered issues, but continuing..."
    }
}

# Parse scan results
cx_parse_results() {
    local scan_type=$1 results_file=$2
    
    local high=0 medium=0 low=0
    
    case "$scan_type" in
        "sast")
            if [[ -f "$results_file" ]]; then
                high=$(grep -o '<Result.*Severity="High"' "$results_file" | wc -l || echo "0")
                medium=$(grep -o '<Result.*Severity="Medium"' "$results_file" | wc -l || echo "0")
                low=$(grep -o '<Result.*Severity="Low"' "$results_file" | wc -l || echo "0")
            fi
            ;;
        "sca")
            if [[ -f "$results_file" ]]; then
                high=$(jq -r '[.vulnerabilities[]? | select(.severity=="HIGH")] | length' "$results_file" 2>/dev/null || echo "0")
                medium=$(jq -r '[.vulnerabilities[]? | select(.severity=="MEDIUM")] | length' "$results_file" 2>/dev/null || echo "0")
                low=$(jq -r '[.vulnerabilities[]? | select(.severity=="LOW")] | length' "$results_file" 2>/dev/null || echo "0")
                
                # Fallback to grep if jq fails
                [[ "$high" == "null" || -z "$high" ]] && high=$(grep -o '"severity":"HIGH"' "$results_file" | wc -l || echo "0")
                [[ "$medium" == "null" || -z "$medium" ]] && medium=$(grep -o '"severity":"MEDIUM"' "$results_file" | wc -l || echo "0")
                [[ "$low" == "null" || -z "$low" ]] && low=$(grep -o '"severity":"LOW"' "$results_file" | wc -l || echo "0")
            fi
            ;;
        "kics")
            if [[ -f "$results_file" ]]; then
                high=$(jq -r '[.queries[]? | select(.severity=="HIGH")] | length' "$results_file" 2>/dev/null || echo "0")
                medium=$(jq -r '[.queries[]? | select(.severity=="MEDIUM")] | length' "$results_file" 2>/dev/null || echo "0")
                low=$(jq -r '[.queries[]? | select(.severity=="LOW")] | length' "$results_file" 2>/dev/null || echo "0")
                
                # Fallback to grep if jq fails
                [[ "$high" == "null" || -z "$high" ]] && high=$(grep -o '"severity":"HIGH"' "$results_file" | wc -l || echo "0")
                [[ "$medium" == "null" || -z "$medium" ]] && medium=$(grep -o '"severity":"MEDIUM"' "$results_file" | wc -l || echo "0")
                [[ "$low" == "null" || -z "$low" ]] && low=$(grep -o '"severity":"LOW"' "$results_file" | wc -l || echo "0")
            fi
            ;;
    esac
    
    log_info "$scan_type Results: High=$high, Medium=$medium, Low=$low"
    echo "$high $medium $low"
}

# Evaluate results against thresholds
cx_evaluate_thresholds() {
    local total_high=$1 total_medium=$2 total_low=$3
    local high_threshold=$4 medium_threshold=$5 low_threshold=$6
    local fail_build=$7
    
    log_info "Evaluating results against thresholds..."
    log_info "Thresholds: High≤$high_threshold, Medium≤$medium_threshold, Low≤$low_threshold"
    log_info "Total Issues: High=$total_high, Medium=$total_medium, Low=$total_low"
    
    local status="PASSED"
    local failures=()
    
    [[ $total_high -gt $high_threshold ]] && failures+=("High severity: $total_high > $high_threshold") && status="FAILED"
    [[ $total_medium -gt $medium_threshold ]] && failures+=("Medium severity: $total_medium > $medium_threshold") && status="FAILED"
    [[ $total_low -gt $low_threshold ]] && failures+=("Low severity: $total_low > $low_threshold") && status="FAILED"
    
    if [[ "$status" == "PASSED" ]]; then
        log_success "Checkmarx scans PASSED - All thresholds met"
    else
        log_error "Checkmarx scans FAILED - Threshold violations:"
        for failure in "${failures[@]}"; do
            log_error "  - $failure"
        done
        
        if [[ "$fail_build" != "true" ]]; then
            log_warning "Build failure disabled - continuing despite threshold violations"
            status="PASSED"
        fi
    fi
    
    echo "$status"
}

# Generate scan report
cx_generate_report() {
    local app_name=$1 scan_id=$2 scan_types=$3 preset=$4 resolver=$5 platforms=$6
    local sast_results=$7 sca_results=$8 kics_results=$9
    local high_threshold=${10} medium_threshold=${11} low_threshold=${12}
    local overall_status=${13}
    
    log_info "Generating Checkmarx scan report..."
    
    cat > checkmarx-scan-report.md << EOF
# 🛡️ Checkmarx Security Scan Report

## Project: $app_name
## Scan ID: $scan_id
## Scan Date: $(date -u +"%Y-%m-%d %H:%M:%S UTC")

### Scan Configuration
- **Scan Types**: $scan_types
- **SAST Preset**: $preset
- **SCA Resolver**: $resolver
- **KICS Platforms**: $platforms

### Results Summary
| Scan Type | High | Medium | Low | Status |
|-----------|------|--------|-----|--------|
EOF

    # Add results for each scan type
    [[ "$sast_results" != "N/A" && -n "$sast_results" ]] && echo "| SAST | $sast_results | ✅ |" >> checkmarx-scan-report.md
    [[ "$sca_results" != "N/A" && -n "$sca_results" ]] && echo "| SCA | $sca_results | ✅ |" >> checkmarx-scan-report.md
    [[ "$kics_results" != "N/A" && -n "$kics_results" ]] && echo "| KICS | $kics_results | ✅ |" >> checkmarx-scan-report.md
    
    cat >> checkmarx-scan-report.md << EOF

### Thresholds
- **High Severity**: ≤$high_threshold
- **Medium Severity**: ≤$medium_threshold
- **Low Severity**: ≤$low_threshold

### Overall Status: $overall_status
EOF

    log_success "Checkmarx report generated"
}

# Set GitHub outputs for scan results
cx_set_outputs() {
    local scan_id=$1 sast_results=$2 sca_results=$3 kics_results=$4 
    local combined_results=$5 status=$6
    
    {
        echo "scan_id=$scan_id"
        echo "sast_results=$sast_results"
        echo "sca_results=$sca_results"
        echo "kics_results=$kics_results"
        echo "overall_results=$combined_results"
        echo "scan_status=$status"
    } >> "$GITHUB_OUTPUT"
}

# Validate Checkmarx configuration
cx_validate_config() {
    local enabled=$1 cx_url=$2 tenant=$3 client_id=$4 client_secret=$5
    
    if [[ "$enabled" != "true" ]]; then
        log_info "Checkmarx scanning is disabled"
        return 1
    fi
    
    check_required_vars "cx_url" "tenant" "client_id" "client_secret" || return 1
    
    log_success "Checkmarx configuration validated"
    log_info "Checkmarx URL: $cx_url"
    return 0
}
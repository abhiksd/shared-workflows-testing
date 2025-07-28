#!/bin/bash

# Script to fix Helm template references for any application
set -e

APP_NAME=$1
HELM_PATH=$2

if [ -z "$APP_NAME" ] || [ -z "$HELM_PATH" ]; then
    echo "Usage: $0 <app-name> <path-to-helm-chart>"
    echo "Example: $0 dces-back4rules apps/dces-back4rules/helm"
    echo "Example: $0 my-app ./helm"
    exit 1
fi

echo "🔧 Fixing Helm template references for: $APP_NAME"
echo "📁 Helm chart path: $HELM_PATH"

if [ ! -d "$HELM_PATH" ]; then
    echo "❌ Error: Helm chart directory '$HELM_PATH' does not exist"
    exit 1
fi

if [ ! -f "$HELM_PATH/Chart.yaml" ]; then
    echo "❌ Error: Chart.yaml not found in '$HELM_PATH'"
    exit 1
fi

# Backup original files
echo "💾 Creating backup..."
cp -r "$HELM_PATH" "${HELM_PATH}.backup.$(date +%Y%m%d_%H%M%S)"

# Update Chart.yaml
echo "📝 Updating Chart.yaml..."
sed -i "s/^name:.*/name: $APP_NAME/" "$HELM_PATH/Chart.yaml"

# Update _helpers.tpl - replace all app-template references with the actual app name
echo "🔧 Updating _helpers.tpl..."
if [ -f "$HELM_PATH/templates/_helpers.tpl" ]; then
    sed -i "s/app-template/$APP_NAME/g" "$HELM_PATH/templates/_helpers.tpl"
else
    echo "⚠️  Warning: _helpers.tpl not found, creating it..."
    cat > "$HELM_PATH/templates/_helpers.tpl" << EOF
{{/*
Expand the name of the chart.
*/}}
{{- define "$APP_NAME.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "$APP_NAME.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- \$name := default .Chart.Name .Values.nameOverride }}
{{- if contains \$name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name \$name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "$APP_NAME.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "$APP_NAME.labels" -}}
helm.sh/chart: {{ include "$APP_NAME.chart" . }}
{{ include "$APP_NAME.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "$APP_NAME.selectorLabels" -}}
app.kubernetes.io/name: {{ include "$APP_NAME.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "$APP_NAME.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "$APP_NAME.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
EOF
fi

# Update all template files to use the correct app name
echo "🔄 Updating template files..."
for template_file in "$HELM_PATH/templates"/*.yaml; do
    if [ -f "$template_file" ]; then
        echo "  - Updating $(basename "$template_file")"
        # Replace app-template references with actual app name
        sed -i "s/app-template/$APP_NAME/g" "$template_file"
    fi
done

# Update values files
echo "📊 Updating values files..."
for values_file in "$HELM_PATH"/values*.yaml; do
    if [ -f "$values_file" ]; then
        echo "  - Updating $(basename "$values_file")"
        # Update application name in values
        sed -i "s/your-app-name/$APP_NAME/g" "$values_file"
        sed -i "s/app-template/$APP_NAME/g" "$values_file"
    fi
done

# Validate the chart
echo "✅ Validating chart..."
if command -v helm >/dev/null 2>&1; then
    if helm lint "$HELM_PATH"; then
        echo "🎉 Chart validation successful!"
    else
        echo "❌ Chart validation failed. Please check the output above."
        exit 1
    fi
else
    echo "⚠️  Helm not found, skipping validation"
fi

echo ""
echo "✅ Template references fixed successfully!"
echo ""
echo "📋 Summary of changes:"
echo "  - Updated Chart.yaml name to: $APP_NAME"
echo "  - Fixed all template references in _helpers.tpl"
echo "  - Updated template files to use correct function names"
echo "  - Updated values files with correct application name"
echo ""
echo "🚀 Next steps:"
echo "  1. Review the changes: git diff $HELM_PATH"
echo "  2. Test the chart: helm template test $HELM_PATH"
echo "  3. Deploy: helm install $APP_NAME $HELM_PATH"
echo ""
echo "💾 Backup created at: ${HELM_PATH}.backup.$(date +%Y%m%d_%H%M%S)"
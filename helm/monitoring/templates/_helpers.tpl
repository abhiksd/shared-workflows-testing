{{/*
Expand the name of the chart.
*/}}
{{- define "aks-monitoring.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "aks-monitoring.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "aks-monitoring.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "aks-monitoring.labels" -}}
helm.sh/chart: {{ include "aks-monitoring.chart" . }}
{{ include "aks-monitoring.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "aks-monitoring.selectorLabels" -}}
app.kubernetes.io/name: {{ include "aks-monitoring.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "aks-monitoring.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "aks-monitoring.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Generate Azure Monitor workspace ID
*/}}
{{- define "aks-monitoring.azureWorkspaceId" -}}
{{- if .Values.azureMonitor.workspaceId }}
{{- .Values.azureMonitor.workspaceId }}
{{- else }}
{{- printf "/subscriptions/%s/resourceGroups/%s/providers/Microsoft.OperationalInsights/workspaces/%s-log-analytics" .Values.global.azureSubscriptionId .Values.global.azureResourceGroup .Values.global.clusterName }}
{{- end }}
{{- end }}
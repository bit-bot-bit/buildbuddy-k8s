{{/*
Expand the name of the chart.
*/}}
{{- define "buildbuddy.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "buildbuddy.fullname" -}}
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
{{- define "buildbuddy.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "buildbuddy.labels" -}}
helm.sh/chart: {{ include "buildbuddy.chart" . }}
{{ include "buildbuddy.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "buildbuddy.selectorLabels" -}}
app.kubernetes.io/name: {{ include "buildbuddy.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "buildbuddy.appSelectorLabels" -}}
{{ include "buildbuddy.selectorLabels" . }}
app.kubernetes.io/component: app
{{- end }}

{{- define "buildbuddy.executorSelectorLabels" -}}
{{ include "buildbuddy.selectorLabels" . }}
app.kubernetes.io/component: executor
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "buildbuddy.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "buildbuddy.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "buildbuddy.executorFullname" -}}
{{- printf "%s-executor" (include "buildbuddy.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "buildbuddy.executorServiceAccountName" -}}
{{- if .Values.executor.serviceAccount.create }}
{{- default (include "buildbuddy.executorFullname" .) .Values.executor.serviceAccount.name }}
{{- else }}
{{- default (include "buildbuddy.serviceAccountName" .) .Values.executor.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "buildbuddy.appConfigObjectName" -}}
{{- if .Values.configExistingSecret }}
{{- .Values.configExistingSecret }}
{{- else }}
{{- printf "%s-config" (include "buildbuddy.fullname" .) }}
{{- end }}
{{- end }}

{{- define "buildbuddy.appConfigObjectKind" -}}
{{- if .Values.configExistingSecret }}secret{{- else }}configMap{{- end }}
{{- end }}

{{- define "buildbuddy.appEnvSecretName" -}}
{{- printf "%s-env" (include "buildbuddy.fullname" .) }}
{{- end }}

{{- define "buildbuddy.executorEnvSecretName" -}}
{{- printf "%s-env" (include "buildbuddy.executorFullname" .) }}
{{- end }}

{{- define "buildbuddy.postgresqlHost" -}}
{{- if .Values.postgresql.fullnameOverride }}
{{- .Values.postgresql.fullnameOverride }}
{{- else }}
{{- printf "%s-postgresql" .Release.Name }}
{{- end }}
{{- end }}

{{- define "buildbuddy.redisHost" -}}
{{- if .Values.redis.fullnameOverride }}
{{- printf "%s-master" .Values.redis.fullnameOverride }}
{{- else }}
{{- printf "%s-redis-master" .Release.Name }}
{{- end }}
{{- end }}

{{- define "buildbuddy.renderedConfig" -}}
{{- $config := deepCopy .Values.config -}}
{{- if .Values.postgresql.enabled }}
  {{- $databaseUrl := printf "postgresql://%s:%s@%s:5432/%s?sslmode=disable" .Values.postgresql.auth.username .Values.postgresql.auth.password (include "buildbuddy.postgresqlHost" .) .Values.postgresql.auth.database -}}
  {{- if not (hasKey $config "database") }}
    {{- $_ := set $config "database" (dict) -}}
  {{- end }}
  {{- $_ := set (get $config "database") "data_source" $databaseUrl -}}
{{- end }}
{{- if .Values.redis.enabled }}
  {{- $redisTarget := printf "%s:6379" (include "buildbuddy.redisHost" .) -}}
  {{- if .Values.redis.auth.enabled }}
    {{- $redisTarget = printf ":%s@%s:6379" .Values.redis.auth.password (include "buildbuddy.redisHost" .) -}}
  {{- end }}
  {{- if not (hasKey $config "cache") }}
    {{- $_ := set $config "cache" (dict) -}}
  {{- end }}
  {{- $_ := set (get $config "cache") "redis_target" $redisTarget -}}
  {{- if not (hasKey $config "remote_execution") }}
    {{- $_ := set $config "remote_execution" (dict) -}}
  {{- end }}
  {{- $_ := set (get $config "remote_execution") "redis_target" $redisTarget -}}
{{- end }}
{{- toYaml $config -}}
{{- end }}

{{- define "buildbuddy.defaultAffinity" -}}
podAntiAffinity:
  preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      podAffinityTerm:
        labelSelector:
          matchExpressions:
            - key: app.kubernetes.io/name
              operator: In
              values:
                - {{ include "buildbuddy.name" . | quote }}
            - key: app.kubernetes.io/component
              operator: In
              values:
                - app
        topologyKey: kubernetes.io/hostname
{{- end }}

{{- define "buildbuddy.executorDefaultAffinity" -}}
podAntiAffinity:
  preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      podAffinityTerm:
        labelSelector:
          matchExpressions:
            - key: app.kubernetes.io/name
              operator: In
              values:
                - {{ include "buildbuddy.name" . | quote }}
            - key: app.kubernetes.io/component
              operator: In
              values:
                - executor
        topologyKey: kubernetes.io/hostname
{{- end }}

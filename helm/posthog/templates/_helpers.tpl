{{/*
Chart name.
*/}}
{{- define "posthog.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Fullname: release-chart.
*/}}
{{- define "posthog.fullname" -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels.
*/}}
{{- define "posthog.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: posthog
{{- end }}

{{/*
Selector labels for a component.
Usage: {{ include "posthog.selectorLabels" (dict "context" . "component" "web") }}
*/}}
{{- define "posthog.selectorLabels" -}}
app.kubernetes.io/name: {{ .context.Chart.Name }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
app.kubernetes.io/component: {{ .component }}
{{- end }}

{{/*
PostHog app image (Python/Django). Tag defaults to appVersion.
*/}}
{{- define "posthog.image" -}}
{{ .Values.images.posthog.repository }}:{{ .Values.images.posthog.tag | default .Chart.AppVersion }}
{{- end }}

{{/*
PostHog Node image. Tag defaults to appVersion.
*/}}
{{- define "posthog.nodeImage" -}}
{{ .Values.images.posthogNode.repository }}:{{ .Values.images.posthogNode.tag | default .Chart.AppVersion }}
{{- end }}

{{/*
ClickHouse image (custom). Tag defaults to <chartVersion>-<appVersion>.
*/}}
{{- define "posthog.clickhouseImage" -}}
{{ .Values.images.clickhouse.repository }}:{{ .Values.images.clickhouse.tag | default (printf "%s-%s" .Chart.Version .Chart.AppVersion) }}
{{- end }}

{{/*
Rust/Go service image helper.
Usage: {{ include "posthog.rustImage" (dict "repo" .Values.images.capture.repository "tag" (.Values.images.capture.tag | default .Chart.AppVersion)) }}
*/}}
{{- define "posthog.rustImage" -}}
{{ .repo }}:{{ .tag }}
{{- end }}

{{/*
Infrastructure image helper (pinned versions, not appVersion).
Usage: {{ include "posthog.infraImage" .Values.images.postgres }}
*/}}
{{- define "posthog.infraImage" -}}
{{ .repository }}:{{ .tag }}
{{- end }}

{{/*
Secret name.
*/}}
{{- define "posthog.secretName" -}}
{{- if .Values.secrets.name -}}
{{ .Values.secrets.name }}
{{- else -}}
{{ include "posthog.fullname" . }}-secrets
{{- end }}
{{- end }}

{{/*
Site URL — defaults to https://<domain>.
*/}}
{{- define "posthog.siteUrl" -}}
{{- if .Values.siteUrl -}}
{{ .Values.siteUrl }}
{{- else -}}
https://{{ .Values.domain }}
{{- end }}
{{- end }}

{{/*
Common environment variables shared by most PostHog services.
*/}}
{{- define "posthog.commonEnv" -}}
- name: PGHOST
  value: {{ include "posthog.fullname" . }}-db
- name: PGUSER
  value: posthog
- name: PGPASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "posthog.secretName" . }}
      key: postgres-password
- name: DATABASE_URL
  value: postgres://posthog:$(PGPASSWORD)@{{ include "posthog.fullname" . }}-db:5432/posthog
- name: CLICKHOUSE_HOST
  value: {{ include "posthog.fullname" . }}-clickhouse
- name: CLICKHOUSE_DATABASE
  value: posthog
- name: CLICKHOUSE_SECURE
  value: "false"
- name: CLICKHOUSE_VERIFY
  value: "false"
- name: CLICKHOUSE_API_USER
  value: api
- name: CLICKHOUSE_API_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "posthog.secretName" . }}
      key: clickhouse-api-password
- name: CLICKHOUSE_APP_USER
  value: app
- name: CLICKHOUSE_APP_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "posthog.secretName" . }}
      key: clickhouse-app-password
- name: REDIS_URL
  value: redis://{{ include "posthog.fullname" . }}-redis:6379/
- name: KAFKA_HOSTS
  value: {{ include "posthog.fullname" . }}-kafka:9092
{{- if eq .Values.objectStorage.type "external" }}
- name: OBJECT_STORAGE_ENDPOINT
  value: {{ .Values.objectStorage.external.endpoint | quote }}
{{- else }}
- name: OBJECT_STORAGE_ENDPOINT
  value: http://{{ include "posthog.fullname" . }}-seaweedfs:8333
{{- end }}
- name: OBJECT_STORAGE_PUBLIC_ENDPOINT
  value: {{ include "posthog.siteUrl" . }}
- name: OBJECT_STORAGE_ACCESS_KEY_ID
  valueFrom:
    secretKeyRef:
      name: {{ include "posthog.secretName" . }}
      key: s3-access-key-id
- name: OBJECT_STORAGE_SECRET_ACCESS_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "posthog.secretName" . }}
      key: s3-secret-access-key
- name: OBJECT_STORAGE_ENABLED
  value: "true"
{{- if eq .Values.objectStorage.type "external" }}
- name: SESSION_RECORDING_V2_S3_ENDPOINT
  value: {{ .Values.objectStorage.external.endpoint | quote }}
{{- else }}
- name: SESSION_RECORDING_V2_S3_ENDPOINT
  value: http://{{ include "posthog.fullname" . }}-seaweedfs:8333
{{- end }}
- name: SESSION_RECORDING_V2_S3_ACCESS_KEY_ID
  valueFrom:
    secretKeyRef:
      name: {{ include "posthog.secretName" . }}
      key: s3-access-key-id
- name: SESSION_RECORDING_V2_S3_SECRET_ACCESS_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "posthog.secretName" . }}
      key: s3-secret-access-key
- name: SITE_URL
  value: {{ include "posthog.siteUrl" . }}
- name: SECRET_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "posthog.secretName" . }}
      key: posthog-secret
- name: ENCRYPTION_SALT_KEYS
  valueFrom:
    secretKeyRef:
      name: {{ include "posthog.secretName" . }}
      key: encryption-salt-keys
- name: DEPLOYMENT
  value: hobby
- name: IS_BEHIND_PROXY
  value: "true"
- name: DISABLE_SECURE_SSL_REDIRECT
  value: "true"
- name: SECURE_COOKIES
  value: {{ .Values.secureCookies | quote }}
- name: OPT_OUT_CAPTURE
  value: {{ .Values.optOutCapture | quote }}
- name: OTEL_SDK_DISABLED
  value: "true"
- name: OTEL_EXPORTER_OTLP_ENDPOINT
  value: ""
- name: MULTI_ORG_ENABLED
  value: {{ .Values.multiOrgEnabled | quote }}
- name: DISABLE_PAID_FEATURE_SHOWCASING
  value: {{ .Values.disablePaidFeatureShowcasing | quote }}
- name: CAPTURE_INTERNAL_METRICS
  value: {{ .Values.captureInternalMetrics | quote }}
- name: ASYNC_EVENT_ACTION_MAPPING
  value: {{ .Values.asyncEventActionMapping | quote }}
- name: ACTION_EVENT_MAPPING_INTERVAL_SECONDS
  value: {{ .Values.actionEventMappingIntervalSeconds | quote }}
- name: DEBUG_QUERIES
  value: {{ .Values.debugQueries | quote }}
- name: CLICKHOUSE_DISABLE_EXTERNAL_SCHEMAS
  value: {{ .Values.clickhouseDisableExternalSchemas | quote }}
- name: LOG_LEVEL
  value: {{ .Values.logLevel | quote }}
- name: MATERIALIZE_COLUMNS_ANALYSIS_PERIOD_HOURS
  value: {{ .Values.materializeColumnsAnalysisPeriodHours | quote }}
- name: MATERIALIZE_COLUMNS_BACKFILL_PERIOD_DAYS
  value: {{ .Values.materializeColumnsBackfillPeriodDays | quote }}
- name: MATERIALIZE_COLUMNS_MAX_AT_ONCE
  value: {{ .Values.materializeColumnsMaxAtOnce | quote }}
- name: MATERIALIZE_COLUMNS_MINIMUM_QUERY_TIME
  value: {{ .Values.materializeColumnsMinimumQueryTime | quote }}
- name: MATERIALIZE_COLUMNS_SCHEDULE_CRON
  value: {{ .Values.materializeColumnsScheduleCron | quote }}
- name: TEAM_NEGATIVE_CACHE_CAPACITY
  value: {{ .Values.teamNegativeCacheCapacity | quote }}
- name: TEAM_NEGATIVE_CACHE_TTL_SECONDS
  value: {{ .Values.teamNegativeCacheTtlSeconds | quote }}
- name: CLEAR_CLICKHOUSE_REMOVED_DATA_SCHEDULE_CRON
  value: {{ .Values.clearClickhouseRemovedDataScheduleCron | quote }}
{{- if .Values.sessionRecordingV2MetadataSwitchover }}
- name: SESSION_RECORDING_V2_METADATA_SWITCHOVER
  value: {{ .Values.sessionRecordingV2MetadataSwitchover | quote }}
{{- end }}
{{- if .Values.allowedIpBlocks }}
- name: ALLOWED_IP_BLOCKS
  value: {{ .Values.allowedIpBlocks | quote }}
{{- end }}
{{- if .Values.trustedProxies }}
- name: TRUSTED_PROXIES
  value: {{ .Values.trustedProxies | quote }}
{{- end }}
{{- if .Values.trustAllProxies }}
- name: TRUST_ALL_PROXIES
  value: "true"
{{- end }}
- name: ALLOWED_HOSTS
  value: {{ .Values.allowedHosts | quote }}
{{- if .Values.sso.github.key }}
- name: SOCIAL_AUTH_GITHUB_KEY
  value: {{ .Values.sso.github.key | quote }}
- name: SOCIAL_AUTH_GITHUB_SECRET
  value: {{ .Values.sso.github.secret | quote }}
{{- end }}
{{- if .Values.sso.gitlab.key }}
- name: SOCIAL_AUTH_GITLAB_KEY
  value: {{ .Values.sso.gitlab.key | quote }}
- name: SOCIAL_AUTH_GITLAB_SECRET
  value: {{ .Values.sso.gitlab.secret | quote }}
- name: SOCIAL_AUTH_GITLAB_API_URL
  value: {{ .Values.sso.gitlab.apiUrl | quote }}
{{- end }}
{{- if .Values.sso.google.key }}
- name: SOCIAL_AUTH_GOOGLE_OAUTH2_KEY
  value: {{ .Values.sso.google.key | quote }}
- name: SOCIAL_AUTH_GOOGLE_OAUTH2_SECRET
  value: {{ .Values.sso.google.secret | quote }}
{{- end }}
{{- if .Values.githubToken }}
- name: GITHUB_TOKEN
  value: {{ .Values.githubToken | quote }}
{{- end }}
{{- if .Values.gitlabToken }}
- name: GITLAB_TOKEN
  value: {{ .Values.gitlabToken | quote }}
{{- end }}
{{- if .Values.npmToken }}
- name: NPM_TOKEN
  value: {{ .Values.npmToken | quote }}
{{- end }}
{{- end }}

{{/*
PVC spec helper.
Usage: {{ include "posthog.pvcSpec" (dict "size" .Values.persistence.postgres.size "storageClass" .Values.persistence.postgres.storageClass) }}
*/}}
{{- define "posthog.pvcSpec" -}}
accessModes:
  - ReadWriteOnce
resources:
  requests:
    storage: {{ .size }}
{{- if .storageClass }}
storageClassName: {{ .storageClass }}
{{- end }}
{{- end }}

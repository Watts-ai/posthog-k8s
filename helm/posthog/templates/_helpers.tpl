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
PostHog app image (Python/Django).
*/}}
{{- define "posthog.image" -}}
{{ .Values.images.posthog.repository }}:{{ .Values.images.posthog.tag }}
{{- end }}

{{/*
PostHog Node image.
*/}}
{{- define "posthog.nodeImage" -}}
{{ .Values.images.posthogNode.repository }}:{{ .Values.images.posthogNode.tag }}
{{- end }}

{{/*
ClickHouse image (custom). Tag defaults to <chartVersion>-<appVersion>.
*/}}
{{- define "posthog.clickhouseImage" -}}
{{ .Values.images.clickhouse.repository }}:{{ .Values.images.clickhouse.tag | default (printf "%s-%s" .Chart.Version .Chart.AppVersion) }}
{{- end }}

{{/*
Rust/Go service image helper.
Usage: {{ include "posthog.rustImage" (dict "repo" .Values.images.capture.repository "tag" .Values.images.capture.tag) }}
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
  value: {{ if eq .Values.postgres.type "external" }}{{ .Values.postgres.external.host }}{{ else }}{{ include "posthog.fullname" . }}-db{{ end }}
- name: PGUSER
  value: posthog
- name: PGPASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "posthog.secretName" . }}
      key: postgres-password
- name: DATABASE_URL
  value: postgres://posthog:$(PGPASSWORD)@$(PGHOST):{{ if eq .Values.postgres.type "external" }}{{ .Values.postgres.external.port }}{{ else }}5432{{ end }}/posthog
{{- if and (eq .Values.postgres.type "external") .Values.postgres.external.sslMode }}
- name: POSTHOG_POSTGRES_SSL_MODE
  value: {{ .Values.postgres.external.sslMode | quote }}
{{- end }}
{{- if and (eq .Values.postgres.type "external") .Values.postgres.external.sslCa }}
- name: POSTHOG_POSTGRES_CLI_SSL_CA
  value: {{ .Values.postgres.external.sslCa | quote }}
{{- end }}
{{- if and (eq .Values.postgres.type "external") .Values.postgres.external.sslCert }}
- name: POSTHOG_POSTGRES_CLI_SSL_CRT
  value: {{ .Values.postgres.external.sslCert | quote }}
{{- end }}
{{- if and (eq .Values.postgres.type "external") .Values.postgres.external.sslKey }}
- name: POSTHOG_POSTGRES_CLI_SSL_KEY
  value: {{ .Values.postgres.external.sslKey | quote }}
{{- end }}
- name: CLICKHOUSE_HOST
  value: {{ if eq .Values.clickhouse.type "external" }}{{ .Values.clickhouse.external.host }}{{ else }}{{ include "posthog.fullname" . }}-clickhouse{{ end }}
- name: CLICKHOUSE_DATABASE
  value: posthog
- name: CLICKHOUSE_SECURE
  value: {{ if eq .Values.clickhouse.type "external" }}{{ .Values.clickhouse.external.secure | quote }}{{ else }}"false"{{ end }}
- name: CLICKHOUSE_VERIFY
  value: {{ if eq .Values.clickhouse.type "external" }}{{ .Values.clickhouse.external.verify | quote }}{{ else }}"false"{{ end }}
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
  value: {{ if eq .Values.redis.type "external" }}{{ .Values.redis.external.url }}{{ else }}redis://{{ include "posthog.fullname" . }}-redis:6379/{{ end }}
- name: KAFKA_HOSTS
  value: {{ if eq .Values.kafka.type "external" }}{{ .Values.kafka.external.hosts }}{{ else }}{{ include "posthog.fullname" . }}-kafka:9092{{ end }}
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
{{- if .Values.sso.github.enabled }}
- name: SOCIAL_AUTH_GITHUB_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "posthog.secretName" . }}
      key: github-oauth-key
- name: SOCIAL_AUTH_GITHUB_SECRET
  valueFrom:
    secretKeyRef:
      name: {{ include "posthog.secretName" . }}
      key: github-oauth-secret
{{- end }}
{{- if .Values.sso.gitlab.enabled }}
- name: SOCIAL_AUTH_GITLAB_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "posthog.secretName" . }}
      key: gitlab-oauth-key
- name: SOCIAL_AUTH_GITLAB_SECRET
  valueFrom:
    secretKeyRef:
      name: {{ include "posthog.secretName" . }}
      key: gitlab-oauth-secret
- name: SOCIAL_AUTH_GITLAB_API_URL
  value: {{ .Values.sso.gitlab.apiUrl | quote }}
{{- end }}
{{- if .Values.sso.google.enabled }}
- name: SOCIAL_AUTH_GOOGLE_OAUTH2_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "posthog.secretName" . }}
      key: google-oauth-key
- name: SOCIAL_AUTH_GOOGLE_OAUTH2_SECRET
  valueFrom:
    secretKeyRef:
      name: {{ include "posthog.secretName" . }}
      key: google-oauth-secret
{{- end }}
{{- if .Values.email.enabled }}
- name: EMAIL_ENABLED
  value: "true"
- name: EMAIL_HOST
  value: {{ .Values.email.host | quote }}
- name: EMAIL_PORT
  value: {{ .Values.email.port | quote }}
{{- if .Values.email.user }}
- name: EMAIL_HOST_USER
  value: {{ .Values.email.user | quote }}
{{- end }}
{{- if .Values.email.password }}
- name: EMAIL_HOST_PASSWORD
  value: {{ .Values.email.password | quote }}
{{- end }}
- name: EMAIL_USE_TLS
  value: {{ .Values.email.useTls | quote }}
- name: EMAIL_USE_SSL
  value: {{ .Values.email.useSsl | quote }}
{{- if .Values.email.defaultFrom }}
- name: EMAIL_DEFAULT_FROM
  value: {{ .Values.email.defaultFrom | quote }}
{{- end }}
{{- end }}
{{- if .Values.slack.clientId }}
- name: SLACK_APP_CLIENT_ID
  value: {{ .Values.slack.clientId | quote }}
- name: SLACK_APP_CLIENT_SECRET
  value: {{ .Values.slack.clientSecret | quote }}
- name: SLACK_APP_SIGNING_SECRET
  value: {{ .Values.slack.signingSecret | quote }}
{{- end }}
- name: SKIP_SERVICE_VERSION_REQUIREMENTS
  value: {{ .Values.skipServiceVersionRequirements | quote }}
{{- if .Values.jsUrl }}
- name: JS_URL
  value: {{ .Values.jsUrl | quote }}
{{- end }}
{{- if .Values.kafkaUrlForClickhouse }}
- name: KAFKA_URL_FOR_CLICKHOUSE
  value: {{ .Values.kafkaUrlForClickhouse | quote }}
{{- end }}
{{- if .Values.statsd.host }}
- name: STATSD_HOST
  value: {{ .Values.statsd.host | quote }}
- name: STATSD_PORT
  value: {{ .Values.statsd.port | quote }}
{{- if .Values.statsd.prefix }}
- name: STATSD_PREFIX
  value: {{ .Values.statsd.prefix | quote }}
{{- end }}
{{- end }}
{{- if .Values.workosRadar.enabled }}
- name: WORKOS_RADAR_ENABLED
  value: "true"
- name: WORKOS_RADAR_API_KEY
  value: {{ .Values.workosRadar.apiKey | quote }}
{{- end }}
{{- if .Values.cloudflareTurnstile.siteKey }}
- name: CLOUDFLARE_TURNSTILE_SITE_KEY
  value: {{ .Values.cloudflareTurnstile.siteKey | quote }}
- name: CLOUDFLARE_TURNSTILE_SECRET_KEY
  value: {{ .Values.cloudflareTurnstile.secretKey | quote }}
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

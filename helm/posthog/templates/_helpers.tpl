{{/*
Pinned PostHog app image commits — update these when bumping versions.
*/}}
{{- define "posthog.upstreamCommit" -}}738b8b39bf26cdd6df530ec59cfbf261ff27788c{{- end -}}
{{- define "posthog.wattsCommit" -}}8ac6d52645f267b67dff2ac9337ba0ed67243c20{{- end -}}

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
Variant-specific defaults; explicit values.images.posthog overrides always win.
*/}}
{{- define "posthog.image" -}}
{{- $repo := .Values.images.posthog.repository -}}
{{- $tag := .Values.images.posthog.tag -}}
{{- if not (include "posthog.hasValue" $repo) -}}
  {{- if eq .Values.variant "watts" -}}
    {{- $repo = "ghcr.io/watts-ai/posthog/posthog" -}}
  {{- else -}}
    {{- $repo = "posthog/posthog" -}}
  {{- end -}}
{{- end -}}
{{- if not (include "posthog.hasValue" $tag) -}}
  {{- if eq .Values.variant "watts" -}}
    {{- $tag = printf "watts-%s" (include "posthog.wattsCommit" .) -}}
  {{- else -}}
    {{- $tag = include "posthog.upstreamCommit" . -}}
  {{- end -}}
{{- end -}}
{{ $repo }}:{{ $tag }}
{{- end }}

{{/*
PostHog Node image.
*/}}
{{- define "posthog.nodeImage" -}}
{{ .Values.images.posthogNode.repository }}:{{ .Values.images.posthogNode.tag }}
{{- end }}

{{/*
ClickHouse image (custom). Tag defaults to chart version.
*/}}
{{- define "posthog.clickhouseImage" -}}
{{ .Values.images.clickhouse.repository }}:{{ .Values.images.clickhouse.tag | default .Chart.Version }}
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
Render a single env var entry.
  - string → value: field
  - map   → rendered as-is (e.g. valueFrom: secretKeyRef: ...)
  - other → fail with actionable error
Usage: {{ include "posthog.envValue" (dict "name" "FOO" "value" .Values.foo) }}
*/}}
{{- define "posthog.envValue" -}}
{{- if kindIs "string" .value -}}
- name: {{ .name }}
  value: {{ .value | quote }}
{{- else if kindIs "map" .value -}}
- name: {{ .name }}
{{- toYaml .value | nindent 2 }}
{{- else -}}
{{- fail (printf "values field for env var %s must be a string or map, got %s. Wrap the value in quotes." .name (kindOf .value)) }}
{{- end -}}
{{- end -}}

{{/*
Check if a value is "set" (non-empty string or any map).
Returns "true" or empty string.
Usage: {{- if include "posthog.hasValue" .Values.foo }}
*/}}
{{- define "posthog.hasValue" -}}
{{- if kindIs "map" . -}}true{{- else if and (kindIs "string" .) (ne . "") -}}true{{- end -}}
{{- end -}}

{{/*
Validate all-or-none: if any field is set, all must be set.
Usage: {{ include "posthog.requireTogether" (dict "section" "email" "fields" (dict "host" .Values.email.host "user" .Values.email.user)) }}
*/}}
{{- define "posthog.requireTogether" -}}
{{- $set := list }}
{{- $missing := list }}
{{- range $name, $val := .fields }}
  {{- if include "posthog.hasValue" $val }}
    {{- $set = append $set $name }}
  {{- else }}
    {{- $missing = append $missing $name }}
  {{- end }}
{{- end }}
{{- if and (gt (len $set) 0) (gt (len $missing) 0) }}
  {{- fail (printf "%s: incomplete configuration. Set: [%s]. Missing: [%s]" .section ($set | sortAlpha | join ", ") ($missing | sortAlpha | join ", ")) }}
{{- end }}
{{- end -}}

{{/*
Validate required-with-defaults fields haven't been blanked out.
Only call when section is active.
Usage: {{ include "posthog.requireNonEmpty" (dict "section" "email" "fields" (dict "port" .Values.email.port)) }}
*/}}
{{- define "posthog.requireNonEmpty" -}}
{{- range $name, $val := .fields }}
  {{- if not (include "posthog.hasValue" $val) }}
    {{- if or (kindIs "string" $val) (kindIs "invalid" $val) }}
    {{- fail (printf "%s: '%s' is required but is empty. Provide a value or remove the override to use the default." $.section $name) }}
    {{- else }}
    {{- fail (printf "%s: '%s' must be a string or map, got %s. Wrap the value in quotes." $.section $name (kindOf $val)) }}
    {{- end }}
  {{- end }}
{{- end }}
{{- end -}}

{{/*
Validate optional fields aren't set without their required trigger fields.
Usage: {{ include "posthog.requireGate" (dict "section" "email" "gateName" "host" "gate" .Values.email.host "fields" (dict "password" .Values.email.password)) }}
*/}}
{{- define "posthog.requireGate" -}}
{{- if not (include "posthog.hasValue" .gate) }}
  {{- range $name, $val := .fields }}
    {{- if include "posthog.hasValue" $val }}
      {{- fail (printf "%s: '%s' is set but '%s' is required. Provide '%s' or remove '%s'." $.section $name $.gateName $.gateName $name) }}
    {{- end }}
  {{- end }}
{{- end }}
{{- end -}}

{{/*
Validate variant and gate fork-specific features.
*/}}
{{- define "posthog.validateVariant" -}}
{{- $valid := list "watts" "upstream" -}}
{{- if not (has .Values.variant $valid) -}}
  {{- fail (printf "variant must be one of [%s], got %q" (join ", " $valid) .Values.variant) -}}
{{- end -}}
{{- if eq .Values.variant "upstream" -}}
  {{- if include "posthog.hasValue" .Values.sso.oidc.key -}}
    {{- fail "sso.oidc requires variant: \"watts\". OIDC SSO is a fork-specific feature not available in upstream PostHog." -}}
  {{- end -}}
  {{- if not (kindIs "string" .Values.auth.disablePasswordLogin) -}}
    {{- fail "auth.disablePasswordLogin must be a string, got bool. Wrap the value in quotes." -}}
  {{- else if ne .Values.auth.disablePasswordLogin "false" -}}
    {{- fail "auth.disablePasswordLogin requires variant: \"watts\". Password login control is a fork-specific feature." -}}
  {{- end -}}
  {{- if not (kindIs "string" .Values.auth.disablePasskeyLogin) -}}
    {{- fail "auth.disablePasskeyLogin must be a string, got bool. Wrap the value in quotes." -}}
  {{- else if ne .Values.auth.disablePasskeyLogin "false" -}}
    {{- fail "auth.disablePasskeyLogin requires variant: \"watts\". Passkey login control is a fork-specific feature." -}}
  {{- end -}}
{{- end -}}
{{- end -}}

{{/*
Common environment variables shared by most PostHog services.
*/}}
{{- define "posthog.commonEnv" -}}
{{- include "posthog.validateVariant" . -}}
{{- include "posthog.requireTogether" (dict "section" "email" "fields" (dict "host" .Values.email.host "user" .Values.email.user)) -}}
{{- include "posthog.requireGate" (dict "section" "email" "gateName" "host" "gate" .Values.email.host "fields" (dict "password" .Values.email.password "defaultFrom" .Values.email.defaultFrom)) -}}
{{- include "posthog.requireTogether" (dict "section" "slack" "fields" (dict "clientId" .Values.slack.clientId "clientSecret" .Values.slack.clientSecret "signingSecret" .Values.slack.signingSecret)) -}}
{{- include "posthog.requireTogether" (dict "section" "sso.github" "fields" (dict "key" .Values.sso.github.key "secret" .Values.sso.github.secret)) -}}
{{- include "posthog.requireTogether" (dict "section" "sso.gitlab" "fields" (dict "key" .Values.sso.gitlab.key "secret" .Values.sso.gitlab.secret)) -}}
{{- include "posthog.requireTogether" (dict "section" "sso.google" "fields" (dict "key" .Values.sso.google.key "secret" .Values.sso.google.secret)) -}}
{{- if eq .Values.variant "watts" -}}
{{- include "posthog.requireTogether" (dict "section" "sso.oidc" "fields" (dict "key" .Values.sso.oidc.key "secret" .Values.sso.oidc.secret "endpoint" .Values.sso.oidc.endpoint)) -}}
{{- include "posthog.requireGate" (dict "section" "sso.oidc" "gateName" "key" "gate" .Values.sso.oidc.key "fields" (dict "iconUrl" .Values.sso.oidc.iconUrl "displayName" .Values.sso.oidc.displayName)) -}}
{{- end -}}
{{- include "posthog.requireTogether" (dict "section" "cloudflareTurnstile" "fields" (dict "siteKey" .Values.cloudflareTurnstile.siteKey "secretKey" .Values.cloudflareTurnstile.secretKey)) -}}
{{- include "posthog.requireTogether" (dict "section" "objectStorage" "fields" (dict "accessKeyId" .Values.objectStorage.accessKeyId "secretAccessKey" .Values.objectStorage.secretAccessKey)) -}}
{{- include "posthog.requireGate" (dict "section" "statsd" "gateName" "host" "gate" .Values.statsd.host "fields" (dict "prefix" .Values.statsd.prefix)) -}}
{{- if eq .Values.postgres.type "external" }}
{{ include "posthog.envValue" (dict "name" "PGHOST" "value" .Values.postgres.external.host) }}
{{ include "posthog.envValue" (dict "name" "PGPORT" "value" .Values.postgres.external.port) }}
{{- else }}
- name: PGHOST
  value: {{ include "posthog.fullname" . }}-db
- name: PGPORT
  value: "5432"
{{- end }}
- name: PGUSER
  value: posthog
{{- if include "posthog.hasValue" .Values.postgres.password }}
{{ include "posthog.envValue" (dict "name" "PGPASSWORD" "value" .Values.postgres.password) }}
{{- else }}
- name: PGPASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "posthog.secretName" . }}
      key: postgres-password
{{- end }}
- name: DATABASE_URL
  value: "postgres://posthog:$(PGPASSWORD)@$(PGHOST):$(PGPORT)/posthog"
{{- if eq .Values.postgres.type "external" }}
{{- if include "posthog.hasValue" .Values.postgres.external.sslMode }}
{{ include "posthog.envValue" (dict "name" "POSTHOG_POSTGRES_SSL_MODE" "value" .Values.postgres.external.sslMode) }}
{{- end }}
{{- if include "posthog.hasValue" .Values.postgres.external.sslCa }}
{{ include "posthog.envValue" (dict "name" "POSTHOG_POSTGRES_CLI_SSL_CA" "value" .Values.postgres.external.sslCa) }}
{{- end }}
{{- if include "posthog.hasValue" .Values.postgres.external.sslCert }}
{{ include "posthog.envValue" (dict "name" "POSTHOG_POSTGRES_CLI_SSL_CRT" "value" .Values.postgres.external.sslCert) }}
{{- end }}
{{- if include "posthog.hasValue" .Values.postgres.external.sslKey }}
{{ include "posthog.envValue" (dict "name" "POSTHOG_POSTGRES_CLI_SSL_KEY" "value" .Values.postgres.external.sslKey) }}
{{- end }}
{{- end }}
{{- if eq .Values.clickhouse.type "external" }}
{{ include "posthog.envValue" (dict "name" "CLICKHOUSE_HOST" "value" .Values.clickhouse.external.host) }}
{{- else }}
- name: CLICKHOUSE_HOST
  value: {{ include "posthog.fullname" . }}-clickhouse
{{- end }}
- name: CLICKHOUSE_DATABASE
  value: posthog
{{- if eq .Values.clickhouse.type "external" }}
{{ include "posthog.envValue" (dict "name" "CLICKHOUSE_SECURE" "value" .Values.clickhouse.external.secure) }}
{{ include "posthog.envValue" (dict "name" "CLICKHOUSE_VERIFY" "value" .Values.clickhouse.external.verify) }}
{{- else }}
- name: CLICKHOUSE_SECURE
  value: "false"
- name: CLICKHOUSE_VERIFY
  value: "false"
{{- end }}
- name: CLICKHOUSE_API_USER
  value: api
{{- if include "posthog.hasValue" .Values.clickhouse.apiPassword }}
{{ include "posthog.envValue" (dict "name" "CLICKHOUSE_API_PASSWORD" "value" .Values.clickhouse.apiPassword) }}
{{- else }}
- name: CLICKHOUSE_API_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "posthog.secretName" . }}
      key: clickhouse-api-password
{{- end }}
- name: CLICKHOUSE_APP_USER
  value: app
{{- if include "posthog.hasValue" .Values.clickhouse.appPassword }}
{{ include "posthog.envValue" (dict "name" "CLICKHOUSE_APP_PASSWORD" "value" .Values.clickhouse.appPassword) }}
{{- else }}
- name: CLICKHOUSE_APP_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "posthog.secretName" . }}
      key: clickhouse-app-password
{{- end }}
- name: CLICKHOUSE_LOGS_CLUSTER_HOST
  value: {{ if eq .Values.clickhouse.type "external" }}$(CLICKHOUSE_HOST){{ else }}{{ include "posthog.fullname" . }}-clickhouse{{ end }}
- name: CLICKHOUSE_LOGS_CLUSTER_PORT
  value: "9000"
- name: CLICKHOUSE_LOGS_CLUSTER_SECURE
  value: "false"
{{- if eq .Values.redis.type "external" }}
{{ include "posthog.envValue" (dict "name" "REDIS_URL" "value" .Values.redis.external.url) }}
{{- else }}
- name: REDIS_URL
  value: redis://{{ include "posthog.fullname" . }}-redis:6379/
{{- end }}
{{- if eq .Values.kafka.type "external" }}
{{ include "posthog.envValue" (dict "name" "KAFKA_HOSTS" "value" .Values.kafka.external.hosts) }}
{{- else }}
- name: KAFKA_HOSTS
  value: {{ include "posthog.fullname" . }}-kafka:9092
{{- end }}
{{- range list "KAFKA_CONSUMER_METADATA_BROKER_LIST" "KAFKA_PRODUCER_METADATA_BROKER_LIST" "KAFKA_METRICS_PRODUCER_METADATA_BROKER_LIST" "KAFKA_MONITORING_PRODUCER_METADATA_BROKER_LIST" "KAFKA_CDP_PRODUCER_METADATA_BROKER_LIST" "KAFKA_WARPSTREAM_PRODUCER_METADATA_BROKER_LIST" "KAFKA_INGESTION_PRODUCER_METADATA_BROKER_LIST" "KAFKA_WAREHOUSE_PRODUCER_METADATA_BROKER_LIST" }}
- name: {{ . }}
  value: "$(KAFKA_HOSTS)"
{{- end }}
{{- if eq .Values.objectStorage.type "external" }}
{{ include "posthog.envValue" (dict "name" "OBJECT_STORAGE_ENDPOINT" "value" .Values.objectStorage.external.endpoint) }}
{{- else }}
- name: OBJECT_STORAGE_ENDPOINT
  value: http://{{ include "posthog.fullname" . }}-seaweedfs:8333
{{- end }}
- name: OBJECT_STORAGE_PUBLIC_ENDPOINT
  value: {{ include "posthog.siteUrl" . }}
{{- if include "posthog.hasValue" .Values.objectStorage.accessKeyId }}
{{ include "posthog.envValue" (dict "name" "OBJECT_STORAGE_ACCESS_KEY_ID" "value" .Values.objectStorage.accessKeyId) }}
{{ include "posthog.envValue" (dict "name" "OBJECT_STORAGE_SECRET_ACCESS_KEY" "value" .Values.objectStorage.secretAccessKey) }}
{{- else }}
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
{{- end }}
- name: OBJECT_STORAGE_ENABLED
  value: "true"
- name: SESSION_RECORDING_V2_S3_ENDPOINT
  value: "$(OBJECT_STORAGE_ENDPOINT)"
- name: SESSION_RECORDING_V2_S3_ACCESS_KEY_ID
  value: "$(OBJECT_STORAGE_ACCESS_KEY_ID)"
- name: SESSION_RECORDING_V2_S3_SECRET_ACCESS_KEY
  value: "$(OBJECT_STORAGE_SECRET_ACCESS_KEY)"
- name: SITE_URL
  value: {{ include "posthog.siteUrl" . }}
{{- if include "posthog.hasValue" .Values.secretKey }}
{{ include "posthog.envValue" (dict "name" "SECRET_KEY" "value" .Values.secretKey) }}
{{- else }}
- name: SECRET_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "posthog.secretName" . }}
      key: posthog-secret
{{- end }}
{{- if include "posthog.hasValue" .Values.encryptionSaltKeys }}
{{ include "posthog.envValue" (dict "name" "ENCRYPTION_SALT_KEYS" "value" .Values.encryptionSaltKeys) }}
{{- else }}
- name: ENCRYPTION_SALT_KEYS
  valueFrom:
    secretKeyRef:
      name: {{ include "posthog.secretName" . }}
      key: encryption-salt-keys
{{- end }}
- name: DEPLOYMENT
  value: hobby
- name: IS_BEHIND_PROXY
  value: "true"
- name: DISABLE_SECURE_SSL_REDIRECT
  value: "true"
- name: OTEL_SDK_DISABLED
  value: "true"
- name: OTEL_EXPORTER_OTLP_ENDPOINT
  value: ""
{{ include "posthog.envValue" (dict "name" "SECURE_COOKIES" "value" .Values.secureCookies) }}
{{ include "posthog.envValue" (dict "name" "OPT_OUT_CAPTURE" "value" .Values.optOutCapture) }}
{{ include "posthog.envValue" (dict "name" "MULTI_ORG_ENABLED" "value" .Values.multiOrgEnabled) }}
{{ include "posthog.envValue" (dict "name" "DISABLE_PAID_FEATURE_SHOWCASING" "value" .Values.disablePaidFeatureShowcasing) }}
{{ include "posthog.envValue" (dict "name" "CAPTURE_INTERNAL_METRICS" "value" .Values.captureInternalMetrics) }}
{{ include "posthog.envValue" (dict "name" "ASYNC_EVENT_ACTION_MAPPING" "value" .Values.asyncEventActionMapping) }}
{{ include "posthog.envValue" (dict "name" "ACTION_EVENT_MAPPING_INTERVAL_SECONDS" "value" .Values.actionEventMappingIntervalSeconds) }}
{{ include "posthog.envValue" (dict "name" "DEBUG_QUERIES" "value" .Values.debugQueries) }}
{{ include "posthog.envValue" (dict "name" "CLICKHOUSE_DISABLE_EXTERNAL_SCHEMAS" "value" .Values.clickhouseDisableExternalSchemas) }}
{{ include "posthog.envValue" (dict "name" "LOG_LEVEL" "value" .Values.logLevel) }}
{{ include "posthog.envValue" (dict "name" "MATERIALIZE_COLUMNS_ANALYSIS_PERIOD_HOURS" "value" .Values.materializeColumnsAnalysisPeriodHours) }}
{{ include "posthog.envValue" (dict "name" "MATERIALIZE_COLUMNS_BACKFILL_PERIOD_DAYS" "value" .Values.materializeColumnsBackfillPeriodDays) }}
{{ include "posthog.envValue" (dict "name" "MATERIALIZE_COLUMNS_MAX_AT_ONCE" "value" .Values.materializeColumnsMaxAtOnce) }}
{{ include "posthog.envValue" (dict "name" "MATERIALIZE_COLUMNS_MINIMUM_QUERY_TIME" "value" .Values.materializeColumnsMinimumQueryTime) }}
{{ include "posthog.envValue" (dict "name" "MATERIALIZE_COLUMNS_SCHEDULE_CRON" "value" .Values.materializeColumnsScheduleCron) }}
{{ include "posthog.envValue" (dict "name" "TEAM_NEGATIVE_CACHE_CAPACITY" "value" .Values.teamNegativeCacheCapacity) }}
{{ include "posthog.envValue" (dict "name" "TEAM_NEGATIVE_CACHE_TTL_SECONDS" "value" .Values.teamNegativeCacheTtlSeconds) }}
{{ include "posthog.envValue" (dict "name" "CLEAR_CLICKHOUSE_REMOVED_DATA_SCHEDULE_CRON" "value" .Values.clearClickhouseRemovedDataScheduleCron) }}
{{- if include "posthog.hasValue" .Values.sessionRecordingV2MetadataSwitchover }}
{{ include "posthog.envValue" (dict "name" "SESSION_RECORDING_V2_METADATA_SWITCHOVER" "value" .Values.sessionRecordingV2MetadataSwitchover) }}
{{- end }}
{{- if include "posthog.hasValue" .Values.allowedIpBlocks }}
{{ include "posthog.envValue" (dict "name" "ALLOWED_IP_BLOCKS" "value" .Values.allowedIpBlocks) }}
{{- end }}
{{- if include "posthog.hasValue" .Values.trustedProxies }}
{{ include "posthog.envValue" (dict "name" "TRUSTED_PROXIES" "value" .Values.trustedProxies) }}
{{- end }}
{{ include "posthog.envValue" (dict "name" "TRUST_ALL_PROXIES" "value" .Values.trustAllProxies) }}
{{ include "posthog.envValue" (dict "name" "ALLOWED_HOSTS" "value" .Values.allowedHosts) }}
{{- if eq .Values.variant "watts" }}
{{ include "posthog.envValue" (dict "name" "DISABLE_PASSWORD_LOGIN" "value" .Values.auth.disablePasswordLogin) }}
{{ include "posthog.envValue" (dict "name" "DISABLE_PASSKEY_LOGIN" "value" .Values.auth.disablePasskeyLogin) }}
{{- end }}
{{- if include "posthog.hasValue" .Values.sso.github.key }}
{{ include "posthog.envValue" (dict "name" "SOCIAL_AUTH_GITHUB_KEY" "value" .Values.sso.github.key) }}
{{ include "posthog.envValue" (dict "name" "SOCIAL_AUTH_GITHUB_SECRET" "value" .Values.sso.github.secret) }}
{{ end }}
{{- if include "posthog.hasValue" .Values.sso.gitlab.key }}
{{- include "posthog.requireNonEmpty" (dict "section" "sso.gitlab" "fields" (dict "apiUrl" .Values.sso.gitlab.apiUrl)) }}
{{ include "posthog.envValue" (dict "name" "SOCIAL_AUTH_GITLAB_KEY" "value" .Values.sso.gitlab.key) }}
{{ include "posthog.envValue" (dict "name" "SOCIAL_AUTH_GITLAB_SECRET" "value" .Values.sso.gitlab.secret) }}
{{ include "posthog.envValue" (dict "name" "SOCIAL_AUTH_GITLAB_API_URL" "value" .Values.sso.gitlab.apiUrl) }}
{{ end }}
{{- if include "posthog.hasValue" .Values.sso.google.key }}
{{ include "posthog.envValue" (dict "name" "SOCIAL_AUTH_GOOGLE_OAUTH2_KEY" "value" .Values.sso.google.key) }}
{{ include "posthog.envValue" (dict "name" "SOCIAL_AUTH_GOOGLE_OAUTH2_SECRET" "value" .Values.sso.google.secret) }}
{{ end }}
{{- if eq .Values.variant "watts" }}
{{- if include "posthog.hasValue" .Values.sso.oidc.key }}
{{ include "posthog.envValue" (dict "name" "SOCIAL_AUTH_OIDC_OIDC_ENDPOINT" "value" .Values.sso.oidc.endpoint) }}
{{ include "posthog.envValue" (dict "name" "SOCIAL_AUTH_OIDC_KEY" "value" .Values.sso.oidc.key) }}
{{ include "posthog.envValue" (dict "name" "SOCIAL_AUTH_OIDC_SECRET" "value" .Values.sso.oidc.secret) }}
{{- if include "posthog.hasValue" .Values.sso.oidc.iconUrl }}
{{ include "posthog.envValue" (dict "name" "SOCIAL_AUTH_OIDC_ICON_URL" "value" .Values.sso.oidc.iconUrl) }}
{{ end }}
{{- if include "posthog.hasValue" .Values.sso.oidc.displayName }}
{{ include "posthog.envValue" (dict "name" "SOCIAL_AUTH_OIDC_DISPLAY_NAME" "value" .Values.sso.oidc.displayName) }}
{{ end }}
{{ end }}
{{- end }}
{{- if include "posthog.hasValue" .Values.email.host }}
{{- include "posthog.requireNonEmpty" (dict "section" "email" "fields" (dict "port" .Values.email.port "useTLS" .Values.email.useTLS "useSSL" .Values.email.useSSL)) }}
- name: EMAIL_ENABLED
  value: "true"
{{ include "posthog.envValue" (dict "name" "EMAIL_HOST" "value" .Values.email.host) }}
{{ include "posthog.envValue" (dict "name" "EMAIL_PORT" "value" .Values.email.port) }}
{{ include "posthog.envValue" (dict "name" "EMAIL_HOST_USER" "value" .Values.email.user) }}
{{- if include "posthog.hasValue" .Values.email.password }}
{{ include "posthog.envValue" (dict "name" "EMAIL_HOST_PASSWORD" "value" .Values.email.password) }}
{{ end }}
{{ include "posthog.envValue" (dict "name" "EMAIL_USE_TLS" "value" .Values.email.useTLS) }}
{{ include "posthog.envValue" (dict "name" "EMAIL_USE_SSL" "value" .Values.email.useSSL) }}
{{- if include "posthog.hasValue" .Values.email.defaultFrom }}
{{ include "posthog.envValue" (dict "name" "EMAIL_DEFAULT_FROM" "value" .Values.email.defaultFrom) }}
{{ end }}
{{ end }}
- name: TEMPORAL_HOST
  value: {{ include "posthog.fullname" . }}-temporal
{{ include "posthog.envValue" (dict "name" "SKIP_SERVICE_VERSION_REQUIREMENTS" "value" .Values.skipServiceVersionRequirements) }}
{{- if include "posthog.hasValue" .Values.jsUrl }}
{{ include "posthog.envValue" (dict "name" "JS_URL" "value" .Values.jsUrl) }}
{{ end }}
{{- if include "posthog.hasValue" .Values.kafkaUrlForClickhouse }}
{{ include "posthog.envValue" (dict "name" "KAFKA_URL_FOR_CLICKHOUSE" "value" .Values.kafkaUrlForClickhouse) }}
{{ end }}
{{- if include "posthog.hasValue" .Values.statsd.host }}
{{- include "posthog.requireNonEmpty" (dict "section" "statsd" "fields" (dict "port" .Values.statsd.port)) }}
{{ include "posthog.envValue" (dict "name" "STATSD_HOST" "value" .Values.statsd.host) }}
{{ include "posthog.envValue" (dict "name" "STATSD_PORT" "value" .Values.statsd.port) }}
{{- if include "posthog.hasValue" .Values.statsd.prefix }}
{{ include "posthog.envValue" (dict "name" "STATSD_PREFIX" "value" .Values.statsd.prefix) }}
{{ end }}
{{ end }}
{{- if include "posthog.hasValue" .Values.workosRadar.apiKey }}
- name: WORKOS_RADAR_ENABLED
  value: "true"
{{ include "posthog.envValue" (dict "name" "WORKOS_RADAR_API_KEY" "value" .Values.workosRadar.apiKey) }}
{{ end }}
{{- if include "posthog.hasValue" .Values.cloudflareTurnstile.siteKey }}
{{ include "posthog.envValue" (dict "name" "CLOUDFLARE_TURNSTILE_SITE_KEY" "value" .Values.cloudflareTurnstile.siteKey) }}
{{ include "posthog.envValue" (dict "name" "CLOUDFLARE_TURNSTILE_SECRET_KEY" "value" .Values.cloudflareTurnstile.secretKey) }}
{{ end }}
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

{{/*
Node scheduling: tolerations, nodeSelector, affinity.
Include in every pod spec.
Usage: {{ include "posthog.scheduling" . | nindent 6 }}
*/}}
{{- define "posthog.scheduling" -}}
{{- with .Values.tolerations }}
tolerations:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.nodeSelector }}
nodeSelector:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end }}

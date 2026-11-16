{{- define "notify-common.labels" -}}
app: {{ .Chart.Name }}
{{- end -}}

{{- define "notify-common.banner" -}}
{{ .Chart.Name }} v{{ .Chart.AppVersion }} ({{ .Values.channel }})
{{- end -}}

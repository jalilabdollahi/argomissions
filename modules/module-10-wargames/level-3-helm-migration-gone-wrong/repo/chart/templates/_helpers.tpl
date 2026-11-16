{{- define "stockroom.claim" -}}
{{- .Values.persistence.claimName | default (printf "%s-storage" .Release.Name) -}}
{{- end -}}

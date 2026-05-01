{{/*
Expand the name of the chart.
*/}}
{{- define "helm_template.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Application/resource name. application_name is kept as v1 fallback to preserve resource names.
*/}}
{{- define "helm_template.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else if .Values.application_name -}}
{{- .Values.application_name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end }}

{{- define "helm_template.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "helm_template.selectorLabels" -}}
app: {{ include "helm_template.fullname" . }}
{{- end }}

{{- define "helm_template.labels" -}}
helm.sh/chart: {{ include "helm_template.chart" . }}
{{ include "helm_template.selectorLabels" . }}
app.kubernetes.io/name: {{ include "helm_template.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.labels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{- define "helm_template.workloadEnabled" -}}
{{- $workload := default dict .Values.workload -}}
{{- if or .Values.deployment .Values.statefulSet -}}
{{- or (and .Values.deployment .Values.deployment.enabled) (and .Values.statefulSet .Values.statefulSet.enabled) -}}
{{- else if hasKey $workload "enabled" -}}
{{- $workload.enabled -}}
{{- else -}}
true
{{- end -}}
{{- end }}

{{- define "helm_template.workloadType" -}}
{{- $workload := default dict .Values.workload -}}
{{- if and .Values.statefulSet .Values.statefulSet.enabled -}}
StatefulSet
{{- else if $workload.type -}}
{{- $workload.type -}}
{{- else -}}
Deployment
{{- end -}}
{{- end }}

{{- define "helm_template.replicas" -}}
{{- $workload := default dict .Values.workload -}}
{{- if and .Values.replicas (eq (int (default 1 $workload.replicas)) 1) -}}
{{- .Values.replicas -}}
{{- else -}}
{{- default (default 1 .Values.replicas) $workload.replicas -}}
{{- end -}}
{{- end }}

{{- define "helm_template.revisionHistoryLimit" -}}
{{- $workload := default dict .Values.workload -}}
{{- default 3 $workload.revisionHistoryLimit -}}
{{- end }}

{{- define "helm_template.image" -}}
{{- $image := default dict .Values.image -}}
{{- if kindIs "map" $image -}}
{{- printf "%s:%s" (default "nginx" $image.repository) (default "stable-alpine" $image.tag) -}}
{{- else -}}
{{- $image -}}
{{- end -}}
{{- end }}

{{- define "helm_template.imagePullPolicy" -}}
{{- $image := default dict .Values.image -}}
{{- if kindIs "map" $image -}}
{{- default (default "IfNotPresent" .Values.imagePullPolicy) $image.pullPolicy -}}
{{- else -}}
{{- default "IfNotPresent" .Values.imagePullPolicy -}}
{{- end -}}
{{- end }}

{{- define "helm_template.containerName" -}}
{{- $container := default dict .Values.container -}}
{{- default (include "helm_template.fullname" .) $container.name -}}
{{- end }}

{{- define "helm_template.imagePullSecrets" -}}
{{- $image := default dict .Values.image -}}
{{- if and .Values.imagePullSecrets .Values.imagePullSecrets.name }}
imagePullSecrets:
  - name: {{ .Values.imagePullSecrets.name }}
{{- else if and (kindIs "map" $image) $image.pullSecrets }}
imagePullSecrets:
{{ toYaml $image.pullSecrets }}
{{- end }}
{{- end }}

{{- define "helm_template.podMetadata" -}}
{{- $workload := default dict .Values.workload -}}
{{- $podAnnotations := default .Values.annotations $workload.podAnnotations -}}
{{- $podLabels := default dict $workload.podLabels -}}
{{- if $podAnnotations }}
annotations:
{{ toYaml $podAnnotations | indent 2 }}
{{- end }}
labels:
{{ include "helm_template.selectorLabels" . | indent 2 }}
{{- with .Values.labels }}
{{ toYaml . | indent 2 }}
{{- end }}
{{- with $podLabels }}
{{ toYaml . | indent 2 }}
{{- end }}
{{- end }}

{{- define "helm_template.scheduling" -}}
{{- $scheduling := default dict .Values.scheduling -}}
{{- $nodeSelector := default .Values.nodeSelector $scheduling.nodeSelector -}}
{{- $tolerations := default .Values.tolerations $scheduling.tolerations -}}
{{- $affinity := $scheduling.affinity -}}
{{- if $nodeSelector }}
nodeSelector:
{{ toYaml $nodeSelector | indent 2 }}
{{- end }}
{{- if $tolerations }}
tolerations:
{{- if kindIs "slice" $tolerations }}
{{ toYaml $tolerations | indent 2 }}
{{- else }}
  - key: {{ $tolerations.key }}
    operator: Equal
    value: {{ $tolerations.value }}
    effect: {{ $tolerations.effect }}
{{- end }}
{{- end }}
{{- if $affinity }}
affinity:
{{ toYaml $affinity | indent 2 }}
{{- else if .Values.affinity }}
affinity:
{{- if .Values.affinity.nodeAffinity }}
  nodeAffinity:
{{- if .Values.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution }}
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
        - matchExpressions:
            - key: {{ .Values.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.key }}
              operator: In
              values:
                - {{ .Values.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.values }}
{{- end }}
{{- if .Values.affinity.nodeAffinity.preferredDuringSchedulingIgnoredDuringExecution }}
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: {{ .Values.affinity.nodeAffinity.preferredDuringSchedulingIgnoredDuringExecution.weight }}
        preference:
          matchExpressions:
            - key: {{ .Values.affinity.nodeAffinity.preferredDuringSchedulingIgnoredDuringExecution.key }}
              operator: In
              values:
                - {{ .Values.affinity.nodeAffinity.preferredDuringSchedulingIgnoredDuringExecution.values }}
{{- end }}
{{- end }}
{{- if .Values.affinity.podAntiAffinity }}
  podAntiAffinity:
{{- if .Values.affinity.podAntiAffinity.preferredDuringSchedulingIgnoredDuringExecution }}
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: {{ .Values.affinity.podAntiAffinity.preferredDuringSchedulingIgnoredDuringExecution.weight }}
        podAffinityTerm:
          labelSelector:
            matchExpressions:
              - key: {{ .Values.affinity.podAntiAffinity.preferredDuringSchedulingIgnoredDuringExecution.key }}
                operator: In
                values:
                  - {{ .Values.affinity.podAntiAffinity.preferredDuringSchedulingIgnoredDuringExecution.values }}
          topologyKey: {{ .Values.affinity.podAntiAffinity.preferredDuringSchedulingIgnoredDuringExecution.topologyKey }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}

{{- define "helm_template.probe" -}}
{{- $probe := .probe -}}
{{- if $probe.periodSeconds }}
periodSeconds: {{ $probe.periodSeconds }}
{{- end }}
{{- if $probe.initialDelaySeconds }}
initialDelaySeconds: {{ $probe.initialDelaySeconds }}
{{- end }}
{{- if $probe.failureThreshold }}
failureThreshold: {{ $probe.failureThreshold }}
{{- end }}
{{- if $probe.httpGet }}
httpGet:
{{ toYaml $probe.httpGet | indent 2 }}
{{- else if $probe.exec }}
exec:
{{ toYaml $probe.exec | indent 2 }}
{{- end }}
{{- end }}

{{- define "helm_template.probes" -}}
{{- $probes := default dict .Values.probes -}}
{{- $startup := default dict $probes.startup -}}
{{- if and (not $startup.enabled) .Values.startupProbe .Values.startupProbe.enabled -}}
{{- $legacy := dict "periodSeconds" .Values.startupProbe.periodSeconds "failureThreshold" .Values.startupProbe.failureThreshold -}}
{{- if and .Values.startupProbe.httpGet .Values.startupProbe.httpGet.enabled -}}
{{- $_ := set $legacy "httpGet" (dict "port" .Values.startupProbe.httpGet.port "path" .Values.startupProbe.httpGet.path) -}}
{{- end -}}
{{- if and .Values.startupProbe.command .Values.startupProbe.command.enabled -}}
{{- $_ := set $legacy "exec" (dict "command" .Values.startupProbe.command.cmd) -}}
{{- end -}}
{{- $startup = merge (dict "enabled" true) $legacy -}}
{{- end -}}
{{- if $startup.enabled }}
startupProbe:
{{ include "helm_template.probe" (dict "probe" $startup) | indent 2 }}
{{- end }}
{{- $liveness := default dict $probes.liveness -}}
{{- if and (not $liveness.enabled) .Values.livenessProbe .Values.livenessProbe.enabled -}}
{{- $legacy := dict "periodSeconds" .Values.livenessProbe.periodSeconds "initialDelaySeconds" .Values.livenessProbe.initialDelaySeconds -}}
{{- if and .Values.livenessProbe.httpGet .Values.livenessProbe.httpGet.enabled -}}
{{- $_ := set $legacy "httpGet" (dict "port" .Values.livenessProbe.httpGet.port "path" .Values.livenessProbe.httpGet.path) -}}
{{- end -}}
{{- if and .Values.livenessProbe.command .Values.livenessProbe.command.enabled -}}
{{- $_ := set $legacy "exec" (dict "command" .Values.livenessProbe.command.cmd) -}}
{{- end -}}
{{- $liveness = merge (dict "enabled" true) $legacy -}}
{{- end -}}
{{- if $liveness.enabled }}
livenessProbe:
{{ include "helm_template.probe" (dict "probe" $liveness) | indent 2 }}
{{- end }}
{{- end }}

{{- define "helm_template.containerPorts" -}}
{{- $container := default dict .Values.container -}}
{{- if and .Values.service .Values.service.targetPort }}
ports:
  - name: http
    containerPort: {{ default (default 80 .Values.service.port) .Values.service.targetPort }}
    protocol: {{ default "TCP" .Values.service.protocol }}
{{- else if $container.ports }}
ports:
{{ toYaml $container.ports | indent 2 }}
{{- end }}
{{- end }}

{{- define "helm_template.env" -}}
{{- $container := default dict .Values.container -}}
{{- $env := default dict $container.env -}}
{{- $plain := default .Values.envVars $env.plain -}}
{{- $valueFrom := default list $env.valueFrom -}}
{{- $fromSecrets := default list $env.fromSecrets -}}
{{- $fromConfigMaps := default list $env.fromConfigMaps -}}
{{- $hasLegacyRef := and .Values.envVarsRef (kindIs "map" .Values.envVarsRef) -}}
{{- if or $plain $valueFrom $fromSecrets $fromConfigMaps $hasLegacyRef }}
env:
{{- range $name, $value := $plain }}
  - name: {{ $name }}
    value: {{ $value | quote }}
{{- end }}
{{- range $item := $valueFrom }}
  - {{ toYaml $item | nindent 4 | trim }}
{{- end }}
{{- range $item := $fromSecrets }}
  - name: {{ $item.name }}
    valueFrom:
      secretKeyRef:
        name: {{ $item.secretName }}
        key: {{ $item.key }}
{{- end }}
{{- range $item := $fromConfigMaps }}
  - name: {{ $item.name }}
    valueFrom:
      configMapKeyRef:
        name: {{ $item.configMapName }}
        key: {{ $item.key }}
{{- end }}
{{- range $name, $value := .Values.envVarsRef }}
  - name: {{ $name }}
{{ toYaml $value | indent 4 }}
{{- end }}
{{- end }}
{{- end }}

{{- define "helm_template.envFrom" -}}
{{- $container := default dict .Values.container -}}
{{- $envFrom := default dict $container.envFrom -}}
{{- $configMaps := default list $envFrom.configMaps -}}
{{- $secrets := default list $envFrom.secrets -}}
{{- $configMapsCfg := default dict .Values.configMaps -}}
{{- $legacyConfigMap := default dict .Values.configmap -}}
{{- $secretsCfg := default dict .Values.secrets -}}
{{- $hasConfigMap := or $configMaps $configMapsCfg.create $legacyConfigMap.enabled -}}
{{- $hasSecret := or $secrets $secretsCfg.create $secretsCfg.enabled -}}
{{- if or $hasConfigMap $hasSecret }}
envFrom:
{{- range $name := $configMaps }}
  - configMapRef:
      name: {{ $name }}
{{- end }}
{{- if or $configMapsCfg.create $legacyConfigMap.enabled }}
  - configMapRef:
      name: {{ include "helm_template.fullname" . }}
{{- end }}
{{- range $name := $secrets }}
  - secretRef:
      name: {{ $name }}
{{- end }}
{{- if or $secretsCfg.create $secretsCfg.enabled }}
  - secretRef:
      name: {{ include "helm_template.fullname" . }}
{{- end }}
{{- end }}
{{- end }}

{{- define "helm_template.volumeMounts" -}}
{{- $volumesRaw := default dict .Values.volumes -}}
{{- $volumes := dict -}}
{{- if kindIs "map" $volumesRaw }}{{- $volumes = $volumesRaw -}}{{- end -}}
{{- $pvc := default dict $volumes.pvc -}}
{{- $mounts := list -}}
{{- range $claim := default list $pvc.claims }}
{{- if $claim.mountPath }}
{{- $mounts = append $mounts (dict "name" $claim.name "mountPath" $claim.mountPath) -}}
{{- end }}
{{- end }}
{{- range $volume := default list $volumes.existing }}
{{- if $volume.mountPath }}
{{- $mount := dict "name" $volume.name "mountPath" $volume.mountPath -}}
{{- if hasKey $volume "readOnly" }}{{- $_ := set $mount "readOnly" $volume.readOnly -}}{{- end -}}
{{- $mounts = append $mounts $mount -}}
{{- end }}
{{- end }}
{{- if and .Values.persistence .Values.persistence.enabled (kindIs "slice" $volumesRaw) }}
{{- range $volume := default list $volumesRaw }}
{{- $mounts = append $mounts (dict "name" (printf "%s-%s" (include "helm_template.fullname" $) $volume.name) "mountPath" $volume.dir) -}}
{{- end }}
{{- end }}
{{- if $mounts }}
volumeMounts:
{{ toYaml $mounts | indent 2 }}
{{- end }}
{{- end }}

{{- define "helm_template.podVolumes" -}}
{{- $volumesRaw := default dict .Values.volumes -}}
{{- $volumes := dict -}}
{{- if kindIs "map" $volumesRaw }}{{- $volumes = $volumesRaw -}}{{- end -}}
{{- $pvc := default dict $volumes.pvc -}}
{{- $items := list -}}
{{- range $claim := default list $pvc.claims }}
{{- $claimName := default $claim.name $claim.claimName -}}
{{- $items = append $items (dict "name" $claim.name "persistentVolumeClaim" (dict "claimName" $claimName)) -}}
{{- end }}
{{- range $volume := default list $volumes.existing }}
{{- $item := dict "name" $volume.name -}}
{{- if eq $volume.type "secret" -}}
{{- $_ := set $item "secret" (dict "secretName" $volume.secretName) -}}
{{- else if eq $volume.type "configMap" -}}
{{- $_ := set $item "configMap" (dict "name" $volume.configMapName) -}}
{{- end -}}
{{- $items = append $items $item -}}
{{- end }}
{{- if and .Values.persistence .Values.persistence.enabled (kindIs "slice" $volumesRaw) }}
{{- range $volume := default list $volumesRaw }}
{{- $items = append $items (dict "name" (printf "%s-%s" (include "helm_template.fullname" $) $volume.name) "persistentVolumeClaim" (dict "claimName" $volume.pvcName)) -}}
{{- end }}
{{- end }}
{{- if $items }}
volumes:
{{ toYaml $items | indent 2 }}
{{- end }}
{{- end }}

{{- define "helm_template.container" -}}
{{- $container := default dict .Values.container -}}
name: {{ include "helm_template.containerName" . }}
image: {{ include "helm_template.image" . }}
imagePullPolicy: {{ include "helm_template.imagePullPolicy" . }}
{{- $command := default .Values.command $container.command }}
{{- if $command }}
command:
{{ toYaml $command | indent 2 }}
{{- end }}
{{- $args := default .Values.args $container.args }}
{{- if $args }}
args:
{{ toYaml $args | indent 2 }}
{{- end }}
{{ include "helm_template.probes" . }}
{{- if .Values.resources }}
resources:
{{ toYaml .Values.resources | indent 2 }}
{{- end }}
{{ include "helm_template.containerPorts" . }}
{{ include "helm_template.env" . }}
{{ include "helm_template.envFrom" . }}
{{ include "helm_template.volumeMounts" . }}
{{- end }}

{{- define "helm_template.initContainers" -}}
{{- if .Values.initContainers }}
initContainers:
{{ toYaml .Values.initContainers | indent 2 }}
{{- else if .Values.initContainer }}
initContainers:
  - name: init
    image: {{ .Values.initContainer.image }}
    command:
{{ toYaml .Values.initContainer.command | indent 6 }}
{{- if .Values.initContainer.volumeMounts }}
    volumeMounts:
{{- range .Values.initContainer.volumeMounts }}
      - name: {{ include "helm_template.fullname" $ }}-{{ .name }}
        mountPath: {{ .mountPath }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}

{{- define "helm_template.podSpec" -}}
{{ include "helm_template.imagePullSecrets" . }}
{{- $workload := default dict .Values.workload -}}
{{- if $workload.terminationGracePeriodSeconds }}
terminationGracePeriodSeconds: {{ $workload.terminationGracePeriodSeconds }}
{{- else if .Values.terminationGracePeriodSeconds }}
terminationGracePeriodSeconds: {{ .Values.terminationGracePeriodSeconds }}
{{- end }}
{{ include "helm_template.scheduling" . }}
{{ include "helm_template.initContainers" . }}
containers:
  - {{ include "helm_template.container" . | nindent 4 | trim }}
{{ include "helm_template.podVolumes" . }}
{{- end }}

#!/bin/bash

for c in $(docker ps -q); do \
    echo -n "Container Name: $(docker inspect "$c" -f '{{.Name}}') ($c): "; \
    docker inspect "$c" \
    -f '{{range $k, $v := .NetworkSettings.Networks}}{{$k}} Aliases: {{.Aliases}} {{end}}'; \
done

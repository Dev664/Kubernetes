#!/bin/bash

kubectl delete -f hpa/hpa.yml
kubectl delete -f notes-app/notes-service.yml
kubectl delete -f notes-app/notes-app.yml
kubectl delete -f load-generator/load-generator.yml

kubectl delete namespace notes-ns
kubectl delete namespace load-ns

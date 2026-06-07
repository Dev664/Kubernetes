#!/bin/bash

kubectl apply -f namespaces/notes-namespace.yml
kubectl apply -f namespaces/load-namespace.yml

kubectl apply -f notes-app/notes-app.yml
kubectl apply -f notes-app/notes-service.yml

kubectl apply -f hpa/hpa.yml

kubectl apply -f load-generator/load-generator.yml

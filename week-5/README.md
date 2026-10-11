# Week 5, Infrastructure as Code with OpenTofu

## What this does
Defines the Week 4 Flask web app, PostgreSQL database, storage, configuration, and secrets using OpenTofu on Kubernetes.

## Requirements
- OpenTofu
- Running Kubernetes cluster
- week-4-web:latest Docker image
- terraform.tfvars with real values

## Deploy
tofu init
tofu plan
tofu apply

## Verify
kubectl get pods
tofu output -raw port_forward_command

## Tear down
tofu destroy

## Known limitation
The state file contains secrets in plain text and must not be committed to Git.

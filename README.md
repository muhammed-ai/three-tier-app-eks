
# Three-Tier Application on AWS EKS with DevSecOps Pipeline

[![CI](https://github.com/jaiswaladi246/three-tier-app-eks-gitops/actions/workflows/ci.yml/badge.svg)](https://github.com/jaiswaladi246/three-tier-app-eks-gitops/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
![Node](https://img.shields.io/badge/node-20-green)

This project demonstrates a React, Express, and MySQL stack deployed to AWS EKS using a GitHub Actions CI/CD pipeline with automated promotion across QA and production environments.

## Architecture

![Architecture](docs/images/architecture.png)

Incoming traffic flows through an Application Load Balancer (ALB) managed by the AWS Load Balancer Controller, which directs requests to ClusterIP services backing the application pods. Container images are promoted from QA to production without rebuilding, ensuring that the exact artifact tested in QA is what gets deployed to production.

## Technology Stack

Node.js 20, React, MySQL, Docker, Kubernetes (EKS), GitHub Actions, Terraform.

## Project Structure

- `src/` - Application source code (client and server)
- `k8s/` - Kubernetes manifests organized by environment
- `terraform/` - Infrastructure code for EKS cluster and networking
- `docs/` - Documentation and architecture diagrams

## Local Development

    cp .env.example .env
    docker compose up --build

Access the application at http://localhost:5000

![Architecture](docs/images/localenv.png)

![Architecture](docs/images/ui.png)

## Key Takeaways

Implementing the environment promotion workflow highlighted the importance of image consistency: rebuilding container images for each environment introduces risk. By adopting a retag-and-promote strategy, the deployment process eliminates "works in QA but fails in production" issues.


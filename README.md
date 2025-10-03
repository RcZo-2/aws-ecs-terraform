# AWS ECS Fargate Architecture Plan

This document outlines the plan for a resilient and scalable AWS infrastructure using a custom VPC and ECS Fargate.

## Architecture Diagram

Here is a Mermaid diagram illustrating the proposed architecture.

```mermaid
graph TD
    User[User] -- JWT --> APIGW[API Gateway]
    APIGW -- Authorize --> Cognito[Cognito User Pool]
    
    subgraph "AWS Cloud"
        APIGW -- VPC Link --> VPCLink

        subgraph VPC["VPC"]
            VPCLink[VPC Link]

            subgraph "Multi-AZ Deployment"
                direction LR
                subgraph AZA["Availability Zone A"]
                    subgraph "Public Subnet A"
                    end
                    subgraph "Private Enterprice Subnet A"
                        AppServer_A[App Server]
                    end
                    subgraph "Private ECS Subnet A"
                        ALB_A[ALB]
                        FargateTask_A[ECS Fargate Task]
                    end
                end

                subgraph AZB["Availability Zone B"]
                    subgraph "Public Subnet B"
                    end
                    subgraph "Private Enterprice Subnet B"
                        AppServer_B[App Server]
                    end
                    subgraph "Private ECS Subnet B"
                        ALB_B[ALB]
                        FargateTask_B[ECS Fargate Task]
                    end
                end
            end
   
            VPCLink --> ALB_A & ALB_B
            ALB_A --> FargateTask_A
            ALB_B --> FargateTask_B
            
            ECR[ECR Repository] -- Pull Image --> FargateTask_A & FargateTask_B
        end
    end

    style VPC fill:#f9f9f9,stroke:#333,stroke-width:2px
    style AZA fill:#ececff,stroke:#333,stroke-width:1px
    style AZB fill:#ececff,stroke:#333,stroke-width:1px

    style APIGW fill:#cce5ff,stroke:#333,stroke-width:1px
    style Cognito fill:#cce5ff,stroke:#333,stroke-width:1px
    style VPCLink fill:#cce5ff,stroke:#333,stroke-width:1px
    style ALB_A fill:#cce5ff,stroke:#333,stroke-width:1px
    style ALB_B fill:#cce5ff,stroke:#333,stroke-width:1px
    style ECR fill:#cce5ff,stroke:#333,stroke-width:1px

    style FargateTask_A fill:#d4edda,stroke:#333,stroke-width:1px
    style FargateTask_B fill:#d4edda,stroke:#333,stroke-width:1px
```

## Architecture Details

### VPC and Networking

*   **VPC CIDR Blocks:**
    *   **Primary:** `10.0.0.0/16` for general-purpose networking (app servers, databases, etc.).
    *   **Secondary:** `172.10.0.0/16` dedicated to the ECS container network to conserve IP addresses in the primary range.
*   **Availability Zones (AZs):** The architecture spans two AZs for high availability.
*   **Public Subnets:**
    *   One public subnet in each AZ (`10.0.10.0/24` and `10.0.20.0/24`) from the primary CIDR.
    *   These subnets have a route to the Internet Gateway (IGW). They are included to provide a DMZ for any future public-facing resources, but are not used for outbound traffic from the private subnets.
*   **Private "Enterprice" Subnets:**
    *   One private subnet in each AZ (`10.0.1.0/24` and `10.0.2.0/24`) from the primary CIDR.
    *   These are for general application resources like EC2 instances or RDS databases.
    *   Their default route points to the NAT Gateway in their respective AZ.
*   **Private "ECS" Subnets:**
    *   One private subnet in each AZ (`172.10.1.0/24` and `172.10.2.0/24`) created from the **secondary CIDR block**.
    *   These subnets are dedicated to running ECS Fargate tasks and are completely isolated from the public internet.
*   **Inter-Subnet Communication:** A common question is whether a NAT Gateway is needed for resources in the ECS subnets (`172.10.x.x`) to communicate with resources in the App subnets (`10.0.x.x`). **A NAT Gateway is not required for this.** All subnets within a VPC, regardless of their CIDR block, can communicate with each other by default. This is handled by the VPC's built-in router, which automatically creates a `local` route for all associated CIDR blocks, enabling seamless private communication between them.

### ECS Fargate

*   **Multi-AZ Deployment:** The ECS cluster is configured to launch tasks across the dedicated **Private ECS subnets** in both AZs.
*   **Networking Mode:** ECS Fargate tasks will use the `awsvpc` network mode. Each task gets its own Elastic Network Interface (ENI) and a private IP address from the secondary CIDR range (e.g., `172.10.1.x` or `172.10.2.x`), effectively separating container traffic from other application traffic at the network level.

### API Gateway Access

To securely expose the ECS service to the internet, an API Gateway is used as the public-facing entry point. This is achieved through the following components:

*   **API Gateway:** An HTTP API Gateway provides a public endpoint for users to access the service.
*   **VPC Link:** A VPC Link creates a private and secure connection between the API Gateway and the resources within the VPC, without exposing them to the public internet.
*   **Application Load Balancer (ALB):** An internal Application Load Balancer is deployed in the private ECS subnets. It receives traffic from the API Gateway via the VPC Link and distributes it to the ECS Fargate tasks.
*   **Security Groups:** A dedicated security group is attached to the VPC Link. A specific ingress rule is added to the ECS task security group to allow traffic only from the VPC Link's security group on the required port, ensuring a secure and isolated environment.

### Authentication

*   **Cognito User Pool:** A Cognito User Pool is used to manage user authentication. It provides a secure and scalable solution for user sign-up and sign-in.
*   **API Gateway Authorizer:** The API Gateway is configured with a JWT authorizer that uses the Cognito User Pool to validate the JSON Web Tokens (JWTs) sent by the client in the `Authorization` header of the request. This ensures that only authenticated users can access the API.

### ECR Integration

*   **Private Image Storage:** An Amazon ECR (Elastic Container Registry) repository is used to securely store and manage the private container images for the ECS service.
*   **VPC Endpoints:** VPC endpoints for ECR and S3 are deployed in the VPC. This allows the ECS tasks to pull container images from the private ECR repository over the private AWS network, without requiring any internet access.
*   **IAM Permissions:** The ECS task execution role is granted the necessary IAM permissions to pull images from the private ECR repository.

## Deployment Strategy

This project follows a two-phase approach for setup and deployment, separating the static, foundational infrastructure from the dynamic, continuous deployment of the application.

### Phase 1: Static Infrastructure Provisioning (Terraform)

The foundational cloud infrastructure is considered "static" because it is provisioned once and rarely changes. It is managed declaratively using Terraform, and the configuration is located in the `Infra/` directory.

Running `terraform apply` in this directory will provision all the necessary AWS resources, including:
*   VPC, Subnets, and Networking components
*   ECR Repository for container images
*   ECS Cluster
*   API Gateway with a VPC Link
*   Application Load Balancer (ALB) and Target Group
*   Cognito User Pool for authentication
*   Necessary IAM Roles and Security Groups

This approach ensures that the core infrastructure is stable, version-controlled, and can be reproduced consistently.

### Phase 2: Dynamic Application Deployment (CI/CD)

Application deployment is a "dynamic" and frequent process, handled by the `Apps/deploy.sh` script, which is designed to be run in a CI/CD pipeline. This script automates the Continuous Deployment (CD) process and is responsible for:

1.  **Building the Docker Image:** Compiling the application and packaging it into a Docker image.
2.  **Pushing to ECR:** Tagging the new image and pushing it to the ECR repository created in the static infrastructure phase.
3.  **Deploying the ECS Service:** Creating or updating the ECS Task Definition with the new image tag and then deploying it as an ECS Service. The script dynamically fetches the necessary resource IDs from the Terraform state to link the service with the existing infrastructure.

This separation allows developers to deploy new versions of the application frequently and automatically without needing to modify the underlying infrastructure.

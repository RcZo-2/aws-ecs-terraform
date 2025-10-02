#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# Define variables
# These would typically be passed in from a CI/CD pipeline
export AWS_REGION=${AWS_REGION:-"us-east-2"}
export NAMESPACE=${NAMESPACE:-"my-app"}
export ECR_REPOSITORY_URL=${ECR_REPOSITORY_URL}
export ECS_CLUSTER_ID=${ECS_CLUSTER_ID}
export ECS_SUBNET_IDS=${ECS_SUBNET_IDS}
export ECS_SECURITY_GROUP_ID=${ECS_SECURITY_GROUP_ID}
export TARGET_GROUP_ARN=${TARGET_GROUP_ARN}
export SERVICE_DISCOVERY_ARN=${SERVICE_DISCOVERY_ARN}
export API_GATEWAY_ID=${API_GATEWAY_ID}
export NLB_LISTENER_ARN=${NLB_LISTENER_ARN}
export VPC_LINK_ID=${VPC_LINK_ID}
export AUTHORIZER_ID=${AUTHORIZER_ID}
export ECS_TASK_EXECUTION_ROLE_ARN=${ECS_TASK_EXECUTION_ROLE_ARN}

# Create a JSON file for the container definition
cat > container-definitions.json <<EOF
[
  {
    "name": "${NAMESPACE}-nginx",
    "image": "${ECR_REPOSITORY_URL}:latest",
    "essential": true,
    "portMappings": [
      {
        "containerPort": 80,
        "hostPort": 80
      }
    ]
  }
]
EOF

# Register ECS Task Definition
echo "Registering ECS task definition..."
TASK_DEFINITION_ARN=$(aws ecs register-task-definition \
  --family "${NAMESPACE}-task" \
  --network-mode "awsvpc" \
  --requires-compatibilities "FARGATE" \
  --cpu "256" \
  --memory "512" \
  --execution-role-arn "$ECS_TASK_EXECUTION_ROLE_ARN" \
  --container-definitions file://container-definitions.json \
  --query 'taskDefinition.taskDefinitionArn' \
  --output text)

echo "Task definition ARN: $TASK_DEFINITION_ARN"

# Create or Update ECS Service
echo "Creating or updating ECS service..."
SERVICE_EXISTS=$(aws ecs describe-services --cluster "$ECS_CLUSTER_ID" --services "${NAMESPACE}-service" --query 'services[?status!=`INACTIVE`]' --output text)

if [ -z "$SERVICE_EXISTS" ]; then
  echo "Creating new ECS service..."
  aws ecs create-service \
    --cluster "$ECS_CLUSTER_ID" \
    --service-name "${NAMESPACE}-service" \
    --task-definition "$TASK_DEFINITION_ARN" \
    --desired-count 2 \
    --launch-type "FARGATE" \
    --network-configuration "awsvpcConfiguration={subnets=[$ECS_SUBNET_IDS],securityGroups=[$ECS_SECURITY_GROUP_ID]}" \
    --load-balancers "targetGroupArn=$TARGET_GROUP_ARN,containerName=${NAMESPACE}-nginx,containerPort=80" \
    --service-registries "registryArn=$SERVICE_DISCOVERY_ARN"
else
  echo "Updating existing ECS service..."
  aws ecs update-service \
    --cluster "$ECS_CLUSTER_ID" \
    --service "${NAMESPACE}-service" \
    --task-definition "$TASK_DEFINITION_ARN" \
    --desired-count 2
fi

# Create API Gateway Integration
echo "Creating API Gateway integration..."
INTEGRATION_ID=$(aws apigatewayv2 create-integration \
  --api-id "$API_GATEWAY_ID" \
  --integration-type "HTTP_PROXY" \
  --integration-uri "$NLB_LISTENER_ARN" \
  --connection-type "VPC_LINK" \
  --connection-id "$VPC_LINK_ID" \
  --query 'IntegrationId' \
  --output text)

echo "Integration ID: $INTEGRATION_ID"

# Create API Gateway Route
echo "Creating API Gateway route..."
aws apigatewayv2 create-route \
  --api-id "$API_GATEWAY_ID" \
  --route-key "GET /" \
  --target "integrations/$INTEGRATION_ID" \
  --authorization-type "JWT" \
  --authorizer-id "$AUTHORIZER_ID"

# Create API Gateway Stage
echo "Creating API Gateway stage..."
aws apigatewayv2 create-stage \
  --api-id "$API_GATEWAY_ID" \
  --stage-name "$NAMESPACE" \
  --auto-deploy

echo "Deployment script finished."

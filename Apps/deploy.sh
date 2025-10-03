#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# Define variables
# These would typically be passed in from a CI/CD pipeline
export AWS_REGION=${AWS_REGION:-"us-east-2"}
export NAMESPACE=${NAMESPACE:-"my-app"}
export ECR_REPOSITORY_URL=$(cd ../Infra && terraform output -json ecr_repository_url | jq -r .)
export ECS_CLUSTER_ID=$(cd ../Infra && terraform output -json ecs_cluster_id | jq -r .)
export ECS_SUBNET_IDS=$(cd ../Infra && terraform output -json ecs_subnet_ids | jq -r 'join(",")')
export ECS_SECURITY_GROUP_ID=$(cd ../Infra && terraform output -json ecs_security_group_id | jq -r .)
export TARGET_GROUP_ARN=$(cd ../Infra && terraform output -json target_group_arn | jq -r .)
export SERVICE_DISCOVERY_ARN=$(cd ../Infra && terraform output -json service_discovery_arn | jq -r .)
export API_GATEWAY_ID=$(cd ../Infra && terraform output -json api_gateway_id | jq -r .)
export ALB_LISTENER_ARN=$(cd ../Infra && terraform output -json alb_listener_arn | jq -r .)
export VPC_LINK_ID=$(cd ../Infra && terraform output -json vpc_link_id | jq -r .)
export AUTHORIZER_ID=$(cd ../Infra && terraform output -json authorizer_id | jq -r .)
export ECS_TASK_EXECUTION_ROLE_ARN=$(cd ../Infra && terraform output -json ecs_task_execution_role_arn | jq -r .)
export ECS_LOG_GROUP_NAME=$(cd ../Infra && terraform output -json ecs_log_group_name | jq -r .)
export ECS_TASK_CPU=${ECS_TASK_CPU:-"256"}
export ECS_TASK_MEMORY=${ECS_TASK_MEMORY:-"512"}

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
    ],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "${ECS_LOG_GROUP_NAME}",
        "awslogs-region": "${AWS_REGION}",
        "awslogs-stream-prefix": "ecs"
      }
    }
  }
]
EOF

# Register ECS Task Definition
echo "Registering ECS task definition..."
TASK_DEFINITION_ARN=$(aws ecs register-task-definition \
  --family "${NAMESPACE}-task" \
  --network-mode "awsvpc" \
  --requires-compatibilities "FARGATE" \
  --cpu "$ECS_TASK_CPU" \
  --memory "$ECS_TASK_MEMORY" \
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

# Create or Update API Gateway Integration
echo "Checking for existing API Gateway integration..."
EXISTING_INTEGRATION_ID=$(aws apigatewayv2 get-integrations --api-id "$API_GATEWAY_ID" \
  --query "Items[?IntegrationUri=='$ALB_LISTENER_ARN'].IntegrationId" \
  --output text)

if [ -z "$EXISTING_INTEGRATION_ID" ]; then
  echo "Creating API Gateway integration..."
  INTEGRATION_ID=$(aws apigatewayv2 create-integration \
    --api-id "$API_GATEWAY_ID" \
    --integration-type "HTTP_PROXY" \
    --integration-uri "$ALB_LISTENER_ARN" \
    --connection-type "VPC_LINK" \
    --connection-id "$VPC_LINK_ID" \
    --query 'IntegrationId' \
    --output text)
else
  echo "Using existing API Gateway integration..."
  INTEGRATION_ID=$EXISTING_INTEGRATION_ID
fi

echo "Integration ID: $INTEGRATION_ID"

# Create or Update API Gateway Route
echo "Checking for existing API Gateway route..."
EXISTING_ROUTE_ID=$(aws apigatewayv2 get-routes --api-id "$API_GATEWAY_ID" \
  --query "Items[?RouteKey=='GET /'].RouteId" \
  --output text)

if [ -z "$EXISTING_ROUTE_ID" ]; then
  echo "Creating API Gateway route..."
  aws apigatewayv2 create-route \
    --api-id "$API_GATEWAY_ID" \
    --route-key "GET /" \
    --target "integrations/$INTEGRATION_ID" \
    --authorization-type "JWT" \
    --authorizer-id "$AUTHORIZER_ID"
else
  echo "Updating existing API Gateway route..."
  aws apigatewayv2 update-route \
    --api-id "$API_GATEWAY_ID" \
    --route-id "$EXISTING_ROUTE_ID" \
    --target "integrations/$INTEGRATION_ID"
fi

# Create or Update API Gateway Stage
echo "Checking for existing API Gateway stage..."
STAGE_EXISTS=$(aws apigatewayv2 get-stage --api-id "$API_GATEWAY_ID" --stage-name "$NAMESPACE" 2>/dev/null)

if [ -z "$STAGE_EXISTS" ]; then
  echo "Creating API Gateway stage..."
  aws apigatewayv2 create-stage \
    --api-id "$API_GATEWAY_ID" \
    --stage-name "$NAMESPACE" \
    --auto-deploy
else
  echo "Updating API Gateway stage..."
  aws apigatewayv2 update-stage \
    --api-id "$API_GATEWAY_ID" \
    --stage-name "$NAMESPACE" \
    --auto-deploy
fi

echo "Deployment script finished."

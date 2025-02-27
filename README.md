# cloud-infra-base
aka Carpathia

## Package Lambda
```bash
zip carpathia_lambda_function.zip carpathia_lambda_function.py
```

## Terraform Commands

### Init
```bash
terraform init
```

### Plan with a .tfvar file
```bash
terraform plan -var-file="envs/sandbox.tfvars"
```

### Invoke Lambda Function
```bash
aws lambda invoke --function-name LAMBDA_FUNCTION response.json
```

## Architecture
```mermaid
flowchart TD;
    EventBridge["AWS EventBridge Rule"] -->|Invokes| Lambda["AWS Lambda Function"]
    Lambda -->|Store Logs| CW["AWS CloudWatch LogGroup"]
    Lambda -->|Fetch AMI ID Parameter| SM["AWS Systems Manager"]
    Lambda -->|Create or Update| LT["AWS Launch Template"]

    LT -->|Create or Update| ASG["AWS Auto Scaling Group"]
    ASG -->|Find Subnet IDs| Subnets["AWS Subnets"]
    Subnets -->|Attach to ASG| ASG
    
    ASG -->|Launch New Instances| EC2["AWS EC2 Instances"]
```

## S3 to EC2
```mermaid
flowchart TD;

E["/persistent/"]
F["/var/log/podaac/"]
G["/bootstrap/"]
H["/home/ssm-user/"]
    subgraph AWS-S3
        B["var/log/podaac/"]
        C["bootstrap/"]
        D["home/ssm-user/"]
    end

    subgraph EC2

        F --> B
        G --> C
        H --> D
        E -->AWS-S3
    end
```
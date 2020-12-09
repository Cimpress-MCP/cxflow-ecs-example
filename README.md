# CxFlow ECS Example

An example of how to use the cxflow-ecs repository as a module to deploy a cluster.

## The CxFlow Cluster Repository

This uses a CxFlow cluster repository as a module to deploy a CxFlow cluster.  You can find the CxFlow cluster repository here:

https://github.com/Cimpress-MCP/cxflow-ecs

## Usage

To deploy, simply:

1. Clone this repo
2. Adjust the [variables.tf](variables.tf) file as needed
3. Adjust the S3 backend/dynamodb settings in `main.tf`
4. Run terraform like so:

```
terraform init
terraform apply
```

And you'll have a Terraform cluster!

If you want the *really* short instructions then copy and paste the following into a file named `main.tf`, adjust things where requested, and then run terraform.

```
terraform {
  backend "s3" {
    bucket = "[S3_BUCKET_NAME_FOR_STORING_TERRAFORM_STATE]"
    key = "[ANY_FOLDER_NAME]/terraform.tfstate"
    region = "[REGION_FOR_ABOVE_S3_BUCKET]"
  }
}

provider "aws" {
  region = "[AWS_REGION_FOR_CLUSTER]"
}

module "cxflow" {
  source = "git::https://github.com/Cimpress-MCP/cxflow-ecs.git"

  name = "[A NAME FOR YOUR CLUSTER]"
  environment = "PRODUCTION|DEVELOPMENT|ETC"
  tags = {
    "A KEY": "A VALUE",
    "THESE WILL": "BE ATTACHED AS TAGS",
    "TO ALL": "AWS INFRASTRUCTURE"
  }
}
```

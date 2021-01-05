# CxFlow ECS Example

This is an example of how to use the cxflow-ecs repository as a module to deploy a cluster.  This also gives step-by-step instructions on how to fully configure and deploy the ECS cluster, from beginning to end.

## Overview

In order to deploy a fully functional Terraform cluster you need the following:

 1. A Route53 hosted zone in AWS
 2. An AKeyless AWS dynamic secret provider that will give Gitlab the necessary permissions for pushing images/secrets to SSM parameter store
 3. A Checkmarx server
 4. A Checkmarx user for CxFlow to login as
 5. A Gitlab token for CxFlow to use to post comments on Merge Requests
 6. A Gitlab web-hook token
 7. The above secrets stored as static secrets in AKeyless
 8. The [container repository](https://github.com/Cimpress-MCP/cxflow-container) deployed in Gitlab, which is responsible for building the CxFlow container and populating some SSM parameters
 9. A clone of this repository, which uses the [cxflow-ecs cluster repository](https://github.com/Cimpress-MCP/cxflow-container) as a Terraform module to create the cluster infrastructure

In terms of actually building this from scratch I suggest the following order of operations:

 1. Create the necessary secrets and store them in AKeyless
 2. Configure your AWS dynamic secret producer in AKeyless
 3. Configure Gitlab/JWT auth in AKeyless
 4. Deploy the cluster infrastructure with a clone of this repository
 5. Create the CxFlow container with the [container repository](https://github.com/Cimpress-MCP/cxflow-container).

Items #4 and #5 are mutually dependent - the cluster cannot fully deploy without the container being built, but the terraform repo also builds the repository and SSM parameters where the container repository will push artifacts.  This could be untangled by introducing a third repository or some manual infrastructure provisioning, but that isn't really necessary.  If you deploy the cluster via Terraform first the ECS cluster won't be able to launch any tasks, but as soon as the container is pushed up to the repository it will finish deploying automatically.  Therefore, the above order works fine in practice.

## Building the cluster from scratch

### 1. Create the necessary secrets and store them in AKeyless

The repository that builds the container expects to find 5 static secrets in AKeyless.  The paths used for AKeyless in the container repository probably won't work for you.  You can put them wherever you want as long as you updated your copy of the [`.gitlab-ci.yml`](https://github.com/Cimpress-MCP/cxflow-container/blob/main/.gitlab-ci.yml) file accordingly.  Here is what you need:

**Create a Checkmarx user** with the `SAST Reviewer role` **VERIFY CHECKMARX PERMISSIONS**.  CxFlow will use this user to send scan requests to Checkmarx and fetch the summary back out afteward.  The username and password for this user go into AKeyless under a path like:

 `/cxflow/{environment}/checkmarx/username`
 `/cxflow/{environment}/checkmarx/password`

**Create a Gitlab User**.  CxFlow will use this user to post a comment on the merge requests when it initializes a scan as well as to post the scan summary as a comment when the scan finishes.  The user itself needs just minimum permissions, but you need to create a token for the user with the following scopes: `["api", "read_user", "write_repository ", "read_registry"]`.  The token for this user goes in AKeyless under a path like:

`/cxflow/${environment}/gitlab/token`

**Create a webhook for CxFlow**.  Gitlab must send a notice to CxFlow (via a webhook) when an action is taken that requires a scan.  To create a webhook, go to your repository and then:

 1. Select "Settings" -> "Webhooks".  Fill out the following:
 2. URL: the URL to the CxFlow cluster (you will provide this as an input into this repository in the "Deploy the cluster via Terraform" step below)
 3. Secret: Any unique, random value.  This is the webhook token and goes in AKeyless.
 4. Trigger: Set the following two events for triggers: `["Push events", "Merge request events"]`
 5. Click "Add Webhook"!

The secret above is your webhook token which goes in AKeyless under a path like:

`/cxflow/${environment}/gitlab/webhook_token`

**Store the CxFlow client_secret**.  CxFlow has a fixed `client_secret` used for OIDC auth in all CxFlow instances.  It's value may change over time, but currently is `014DF517-39D1-4453-B7B3-9930C563627C` and is currently [documented here](https://github.com/checkmarx-ltd/cx-flow/wiki/Configuration#90-configuration-changes).  Don't ask me why they have a token called "client_secret" that they publish in public documentation.  Regardless, it goes in AKeyless under a path like:

`/cxflow/${environment}/checkmarx/token`

### 2. Configure your AWS dynamic secret provider in AKeyless

The [container repository](https://github.com/Cimpress-MCP/cxflow-container) will fetch secrets from AKeyless and push them to the AWS SSM parameter store.  It will also build a container with Docker and push it to the ECR.  Both those operations require AWS access credentials.  We have used AKeyless to generate those credentials dynamically so that static access credentials don't have to be stored in Gitlab.  Instead, the Gitlab pipeline authenticates to AKeyless and fetches temporary AWS credentials.

[You can find documentation from AKeyless on creating an AWS dynamic secret producer.](https://docs.akeyless.io/docs/aws-producer)  The part specific to this project are the necessary AWS permissions that your generated user will need to push to ECR and SSM.  The following policy is what you need for this project:

```
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Sid": "AllowPushPull",
      "Effect": "Allow",
      "Action": [
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:BatchCheckLayerAvailability",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ],
      "Resource": "arn:aws:ecr:us-east-1:[ACCOUNT_ID]:repository/cxflow-*"
    },
    {
      "Sid": "AllowECRCredentials",
      "Effect": "Allow",
      "Action": "ecr:GetAuthorizationToken",
      "Resource": "*"
    },
    {
      "Sid": "PutSSMParameter",
      "Effect": "Allow",
      "Action": [
        "ssm:PutParameter"
      ],
      "Resource": "arn:aws:ssm:us-east-1:[ACCOUNT_ID]:parameter/cxflow/*"
    }
  ]
}
```

The AKeyless producer is named `/cxflow/${environment}/deploy_from_gitlab` in the container repository, but of course you can adjust that according to your needs.

### 3. Configure Gitlab/JWT auth in AKeyless

The Gitlab pipeline logs into AKeyless using JWT auth.  This works because Gitlab provides a JWT to all running pipelines and publishes it's public key so those JWTs can be verified.  There are claims in the JWT with project id/branch name, allowing you to ensure that AKeyless only accepts pipelines running for your repository.

CimSec has already setup JWT auth in AKeyless and shared it with all Cimpress teams.  You'll just need to attach this to a role with access to the above secrets and set the appropriate subclaim checks.  You can find more details in our [documentation](https://support.security.cimpress.io/hc/en-us/articles/360017410400-Authentication-Method-Gitlab).

Otherwise, you can enabling JWT auth for Gitlab only requires the JWKS URL for Gitlab: `https://gitlab.com/-/jwks`

The access id of your JWT auth method must go in the pipeline.  The access id for Cimpress' Shared Gitlab auth method (`p-ggr5d3vp3b2s`) is already set in the container repository.  If not using that one, replace it with the access id of your own auth method from AKeyless.

### 4. Deploy the cluster via Terraform

At this point in time you are readying to deploy the CxFlow cluster via Terraform.  This also prepares the infrastructure for buiding the container: it will create the ECR repository in AWS and generate the SSM parameters.  The actual configuration of the cluster lives in a [separate repository](https://github.com/Cimpress-MCP/cxflow-container) which this repository uses as a module.  Therefore to prepare and run terraform you must:

 1. Clone this repo
 2. Edit the [`terraform.tfvars`](terraform.tvars) file with:
 2. The name of your Route53 hosted zone
 3. Your desired AWS region for the cluster.
 4. The domain for the cluster.  It must be a sub-domain of your Route53 hosted zone.  An ACM will be registered for it and an A record will be created to point this domain to the load balancer for the cluster.  This is where you will point your Github webhook.
 5. Any desired tags.  They will be attached to all applicable AWS resources.
 6. Next you must update the [`main.tf`](main.tf) file to set proper S3 backend/dynamodb settings for your backend (or remove that section if you want to keep your Terraform state locally)
 4. Run terraform!

Running terraform is as simple as executing these commands from the root directory of this repository:

```
terraform init
terraform apply
```

Your cluster will be deployed, but the ECS service will be unable to launch tasks because there aren't any containers waiting in ECR (assuming you don't have other problems of course!)

### 5. Create the CxFlow container

Last but not least, you must use the [container repository](https://github.com/Cimpress-MCP/cxflow-container) to build a CxFlow container using Docker and push it up to ECR. This uses a CxFlow cluster repository as a module to deploy a CxFlow cluster.  To do that:

 1. Clone the [container repository](https://github.com/Cimpress-MCP/cxflow-container)
 2. Adjust any AKeyless paths in the `.gitlab-ci.yml` file as necessary depending on how you configured AKeyless
 3. Create the necessary pipeline variables in your repository (see the table below)
 4. Push your clone up to your Gitlab repository.

| Variable Name      | Value                                                                                                                             |
|--------------------|-----------------------------------------------------------------------------------------------------------------------------------|
| AWS_DEFAULT_REGION | The AWS region for your cluster                                                                                                   |
| CX_FLOW_SERVER     | The domain for your CxFlow cluster                                                                                                |
| CX_FLOW_VERSION    | The version of CxFlow to use (currently tested with `1.6.15`).  It is used to build the CxFlow download URL                       |
| REGISTRY           | The ECR registry to push to.  Built by Terraform.  Should be something like `[AWS_ACCOUNT_ID].dkr.ecr.[AWS_REGION].amazonaws.com` |

After you set your pipeline variables and push up your new repository to Gitlab, the pipeline will run, your container should be created, secrets will be copied from AKeyless and pushed to SSM Parameter store, and your CxFlow tasks should launch in the ECS service, starting the cluster.

## Updating the cluster

Pushing out new versions of CxFlow looks like this:

 1. Update the `$CX_FLOW_VERSION` variable in the Gitlab Pipeline for the container repository
 2. Re-run the pipeline for the container repository, which will push up a new `latest` container to ECR
 3. Run `terraform apply` in this repository.  That will push a new task definition up to the ECS cluster which will then deploy new tasks and drain the old ones

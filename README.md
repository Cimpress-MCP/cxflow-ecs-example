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
 7. A pre-shared token for CxFlow
 8. The above secrets stored as static secrets in AKeyless
 9. The [container repository](https://github.com/Cimpress-MCP/cxflow-container) deployed in Gitlab, which is responsible for building the CxFlow container and populating some SSM parameters
 10. This repository, which uses the [cxflow-ecs cluster repository](https://github.com/Cimpress-MCP/cxflow-container) as a Terraform module to create the cluster infrastructure

In terms of actually building this from scratch I suggest the following order of operations:

 1. Create the necessary secrets and store them in AKeyless
 2. Configure your AWS dynamic secret producer in AKeyless
 3. Configure Gitlab/JWT auth in AKeyless (so the Gitlab pipeline can login to AKeyless without needing its own static credentials)
 4. Deploy the cluster infrastructure with this repository
 5. Create the container with the [container repository](https://github.com/Cimpress-MCP/cxflow-container).

Items #4 and #5 are mutually dependent - the cluster cannot fully deploy without the container being built, but the terraform repo also builds the repository and SSM parameters where the container repository will push artifacts.  This could be untangled by introducing a third repository or some manual infrastructure provisioning, but that isn't really necessary.  If you deploy the cluster via Terraform first the ECS cluster won't be able to launch any tasks, but as soon as the container is pushed up to the repository it will finish deploying automatically.  Therefore, the above order works fine in practice.

## Updating the cluster

Pushing out new versions of CxFlow is a two step process:

 1. Update the `$CX_FLOW_VERSION` variable in the Gitlab Pipeline for the container repository
 2. Re-run the pipeline for the container repository, which will push up a new `latest` container to ECR
 3. Run `terraform apply` in this repository.  That will push a new task definition up to the ECS cluster which will then deploy new tasks and drain the old ones

## Building the cluster from scratch

### 1. Create the necessary secrets and store them in AKeyless

The repository that builds the container expects to find 5 static secrets in AKeyless.  The paths used for AKeyless in the container repository probably won't work for you.  You can put them wherever you want as long as you updated your copy of the [`.gitlab-ci.yml`](https://github.com/Cimpress-MCP/cxflow-container/blob/main/.gitlab-ci.yml) file accordingly.  Here is what you need:

**Create a Checkmarx user** with the `SAST Reviewer role` **VERIFY CHECKMARX PERMISSIONS**.  CxFlow will use this user to send scan requests to Checkmarx and fetch the summary back out afteward.  The username and password for this user go into AKeyless under a path like:

 `/cxflow/{environment}/checkmarx/username`
 `/cxflow/{environment}/checkmarx/password`

**Create a Gitlab User**.  CxFlow will use this user to post a comment on the merge requests when it initializes a scan as well as to post the scan summary as a comment when the scan finishes.  **INSERT PERMISSIONS FOR GITLAB USER** The token for this user goes in AKeyless under a path like:

`/cxflow/${environment}/gitlab/token`

**Create a webhook for CxFlow**.  Gitlab must send a notice to CxFlow (via a webhook) when an action is taken that requires a scan.  **INSERT STEPS TO CONFIGURE WEBHOOK**.  The webhook token goes in AKeyless under a path like:

`/cxflow/${environment}/gitlab/webhook_token`

**Create a pre-shard secret for CxFlow**.  I have no idea what this is or what it does.  It goes in AKeyless under a path like:

`/cxflow/${environment}/checkmarx/token`

## 1. Deploy the cluster via Terraform

The first step is to use this repository to deploy a CxFlow cluster via Terraform.  This repository uses the cxflow-ecs as a terraform module to do the heavy lifting.

## The CxFlow Cluster Repository

This uses a CxFlow cluster repository as a module to deploy a CxFlow cluster.  You can find the CxFlow cluster repository here:

https://github.com/Cimpress-MCP/cxflow-container

## Using this module to deploy to ECS

To deploy, simply:

1. Clone this repo
2. Adjust the [variables.tf](variables.tf) file as needed
3. Adjust the S3 backend/dynamodb settings in `main.tf`
4. Run terraform like so:

```
terraform init
terraform apply
```

And you'll have a running ECS cluster!

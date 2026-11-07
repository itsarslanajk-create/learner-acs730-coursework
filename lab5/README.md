# Lab 5 - Terraform network, tested in CI against LocalStack

## What I built

One Terraform config that can target real AWS or LocalStack. The switch is the variable use_localstack; localstack.tfvars turns it on and points the provider at http://localhost:4566.

It creates a VPC, two public subnets (for_each), an internet gateway, a route table with its associations, a security group (dynamic ingress), an EC2 web server with user_data, and an optional S3 bucket (count). No ids are hardcoded: AZs come from a data source, the AMI from another, and everything else is wired by reference (e.g. vpc_id = aws_vpc.main.id).

To run it locally:

    docker run -d --name localstack -p 4566:4566 -e SERVICES=ec2,s3,sts,iam localstack/localstack:3.8
    terraform init
    terraform plan -var-file=localstack.tfvars -out=tfplan
    terraform apply -auto-approve tfplan
    terraform destroy -auto-approve -var-file=localstack.tfvars

CI runs fmt/validate first, then plan + apply + destroy against a LocalStack container, only if the first job passed. No AWS credentials anywhere in the workflow.

One fix: the walkthrough's skip_requester_charged isn't a valid provider argument (validate rejected it), so I used skip_requesting_account_id instead.

## Why for_each here and count there

- Subnets: for_each, because each subnet has a name (a, b). Add "c" -> 1 to add. Remove "a" -> 1 to destroy, "b" untouched.
- With count they'd be [0], [1], [2]. Remove the middle one and the rest shift down, so Terraform destroys and recreates two subnets to remove one.
- Bucket: count, because it's just on or off - 0 or 1. Nothing to name.

## Why not plan and apply against real AWS on every pull request

- Cost: every PR would build and destroy real resources. With 27 students that eats the $50 credit fast. LocalStack is free.
- Credentials: CI would need an AWS key in GitHub secrets. In Academy we can't create a scoped IAM user, so it would have to be a broad key, and it can leak.
- Expiry: Academy credentials die after a few hours, so checks would fail for reasons that have nothing to do with the code, and people start ignoring red checks.
- Slow and flaky: rate limits, eventual consistency, PRs colliding in the same account.
- Limit: a green LocalStack run only proves the config is consistent. It doesn't check IAM or boot the instance, so user_data is never tested. A real-AWS run belongs on merge or on a schedule, not on every PR.

## Experiments

### 4 - Bucket turned off
Predicted: artifact_bucket would print null.
Got: apply worked (no bucket), but terraform output artifact_bucket said "Output not found".
Why: one() returns null, and Terraform doesn't keep outputs that are null, so it's just missing. Using [0] instead of one() would crash with an index error when the bucket is off.

### 2 - Removed depends_on
Predicted: the plan wouldn't change.
Got: still "10 to add" - same as before.
Why: depends_on only changes the order, not what gets built. Without it the instance can start before the subnet's internet route exists, so on real AWS the nginx install in user_data would hang with no error. LocalStack never runs user_data, so you can't see this bug there.

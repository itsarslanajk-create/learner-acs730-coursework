# Assignment 1 - Multi-environment deployment

## Introduction

In this assignment I deployed one Terraform configuration as three separate environments: dev, staging and prod. I used separate environments instead of one because each has a different job: dev is for development work, staging is where changes are rehearsed, and prod is where the real workload goes live. Staging and prod are deployed through a GitHub Actions pipeline, with an approval step in front of prod. The pipeline uses only short-lived AWS Academy session credentials, stored on the staging and prod environments, so no long-lived key exists anywhere.

## Module and environments (Tasks 1-2)

The resources live in one module, terraform/modules/web (VPC, two public subnets, internet gateway, route table, security group, EC2 web server, the SSM data source and the CloudWatch alarm), which dev/, staging/ and prod/ all call. The inputs are the values that differ between environments: environment (dev is for development, prod for the real workload), instance_type (prod is bigger), vpc_cidr and public_subnets (10.1, 10.2 and 10.3 so the ranges never overlap), and ssm_parameter_name (each environment reads its own secret). Values that are the same everywhere, like the region, are fixed in the module instead of being inputs.

Each environment has its own state key in one S3 bucket (assignment1/dev, assignment1/staging, assignment1/prod - see evidence/backend-state-keys.txt), because sharing one state file would mean a change or an error in one environment could break another. One secret per environment follows the same reasoning. I made staging the same size as prod (t3.small) so it shows how production will actually behave.

## GitHub Environments and the approval gate (Task 3)

After a merge to main, the staging job starts by itself, but the prod job stops and shows "waiting for review", because prod holds the real workload and only runs after a reviewer approves it. Prod can also only deploy from main, because main is where changes are reviewed through a pull request; without the main-only rule, anyone who can push a branch could send unreviewed code to production. See evidence/environments.json.

## Credentials (Task 4)

The three AWS secrets were moved from the repository to the staging and prod environments, and the repository-level copies were deleted (evidence/secrets-scope.txt). A repository secret can be read by every job in every workflow on any branch; an environment secret can only be read by a job that declares that environment, and for prod only after the approval and only from main. The per-session refresh command is now:

    ./scripts/refresh-gha-creds.sh itsarslanajk-create/learner-acs730-coursework staging prod

The old two-argument form still succeeds but writes repository secrets that no job can read any more.

### OIDC trust policy for the prod role (not deployed)

In a real AWS account the pipeline would use OIDC instead of session keys: GitHub gives each run a signed token, and the prod role trusts only tokens that match these conditions.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:itsarslanajk-create/learner-acs730-coursework:environment:prod"
        }
      }
    }
  ]
}
```

- **Principal (issuer):** only tokens issued by GitHub's token service are trusted, not tokens from any other identity provider.
- **Action:** the token can only be exchanged for this role's temporary credentials.
- **aud:** the token must be meant for AWS STS, so a token issued for another service cannot be replayed here.
- **sub:** only runs of this repository deploying to the prod environment. With a wildcard like repo:itsarslanajk-create/learner-acs730-coursework:* any run from any branch, by anyone with push access, could get prod credentials and skip the approval. Pinning it to environment:prod means only a job that passed the prod reviewer and the main-only branch policy can assume the role.

I could not deploy it because in the AWS Academy Learner Lab IAM writes are denied: we can only use the roles the lab gives us. That is also why in Lab 6 we attached the existing LabInstanceProfile instead of creating one; creating it would fail with AccessDenied.

## Deployment (Task 5)

After merging to main, staging was created automatically, then I reviewed the prod job and approved it, and prod was also created. Each environment applied 10 resources (evidence/staging-apply.txt, evidence/prod-apply.txt, prod-approval-pending.png, prod-approval-approved.png).

## Secrets in SSM Parameter Store (Task 6)

Each environment's placeholder database password is a SecureString parameter, created once by hand before the first plan:

    aws ssm put-parameter --name "/acs730/<env>/db_password" --type SecureString --value "<placeholder>"

Terraform only reads it with a data "aws_ssm_parameter" source and never creates it. The parameter already exists, so any new environment or CI runner can read it; if Terraform also created it, a fresh run would try to read it before it exists and fail. The value never appears in the code (evidence/ssm-parameter.txt shows the name and version only). One caveat: a value read by a data source is stored in the Terraform state, which is why the state bucket has encrypt = true.

## CloudWatch alarm (Task 7)

Each environment has an alarm on the instance's CPUUtilization, above 50% average over 5 minutes. I picked CPU because EC2 reports it even when the server is idle, so the alarm gets real data and leaves INSUFFICIENT_DATA - all three alarms were OK in evidence/cloudwatch-alarm.json. 50% is an early warning: it fires well before the server is maxed out, so there is time to react.

## Recommendation: GitHub Actions or AWS-native? (Task 8)

For a team fully committed to AWS with no multi-cloud plans, I recommend staying with the GitHub Actions pipeline.

1. **Team familiarity.** The team already works in GitHub: pull requests, reviews and the pipeline sit in the same place, and the approval gate in this assignment is on the same page as the code being approved. Moving to CodePipeline means learning a new tool and separating the pipeline from the review.
2. **Nothing to run or patch.** GitHub hosts and patches the runners. Each job gets a clean runner and the team maintains no build servers.
3. **Identity is solvable without keys.** The usual argument for AWS-native is that it runs inside AWS with an IAM role. The OIDC trust policy above closes that gap: GitHub runs get short-lived credentials from a role scoped to one repository and one environment, with nothing stored to leak or rotate.

The downsides I accept: GitHub's runners sit outside the VPC, so reaching private resources would need self-hosted runners, and the audit trail is split between GitHub and CloudTrail instead of being in one place. If the team needed VPC-internal access for every deployment, or a single audit trail was a hard requirement, I would switch to CodePipeline and CodeBuild.

## Teardown (Task 9)

All three environments were destroyed, 10 resources each, and a final check found no instances or alarms left (evidence/destroy-complete.txt). Because the state is shared in S3, the workstation could destroy what the pipeline built.

## Conclusion

The two things I learned in this assignment are that state keys keep environments apart and that secrets should be scoped to the environment that needs them. Separate state keys mean an apply in one environment cannot break another, and environment-scoped secrets mean credentials reach only the job that should have them; OIDC would remove the keys entirely. Next time I would use the OIDC role in a real account instead of session keys, add a terraform plan step on pull requests so reviewers can see what will change before they approve, and watch the workstation's disk space by sharing one Terraform provider cache, since the disk filled up twice during this assignment.

Note: after the first teardown, pushing the evidence and this report to main re-triggered the deploy workflow (it is scoped to assignment1/**), which re-created staging automatically. I cancelled the waiting prod run without approving it, destroyed staging again, and pushed the final files with [skip ci] so no further deployment ran. The appended section of destroy-complete.txt records it.

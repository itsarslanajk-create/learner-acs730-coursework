# Lab 6 - Ansible role over SSM, and a Packer golden AMI

## The three required answers

- **Runner-to-instance mechanism:** Session Manager (SSM). The instances have no port 22 rule and there is no SSH key anywhere; the SSM agent on each instance connects out to AWS over 443, and both my workstation and the GitHub runner reach it with temporary AWS session credentials, so there is no long-lived private key to store or leak and no 0.0.0.0/0 on port 22 for a runner with a changing IP.
- **What changed=0 on a second run proves:** every task checked the real state of the host and found it already matched what the role asks for, so the same playbook is safe to run on a brand-new instance and on one that is already configured, including from a pipeline on every merge.
- **Why deregistering an AMI is not enough:** the AMI is only a pointer; the EBS snapshot behind it is the stored data and the thing that bills, and deregistering leaves it behind. I read the snapshot id from the AMI first, then deregistered, then deleted the snapshot, because once the AMI is gone nothing tells you which snapshot belonged to it.

## Boot-to-ready: converge on boot vs golden AMI

Same script (scripts/boot-to-ready.sh), same start point: the moment I asked AWS for an instance, until the web page answered.

| Path | Seconds | What is inside the number |
| --- | --- | --- |
| Converge on boot (stock AL2023 + Ansible over SSM) | 102 | launch, boot, SSM registration, dnf install, config, service start |
| Golden AMI (Packer, same role baked in) | 22 | launch and boot only; the service starts from the image |

Where the slow path's time went: almost none of it is Ansible's logic. It is waiting for the SSM agent to register, then dnf downloading packages, again for every instance.

A golden AMI moves the cost rather than removing it: the same work ran once at build time (packer build took 3 min 54 s). It wins once you launch more than a couple of instances, and loses if you launch one.

What breaks with golden AMIs: the image is frozen at build time, so later updates are missing until you rebuild, and you can't see what's inside without the build log.

What breaks with converge on boot: every launch depends on package mirrors and SSM being reachable right then. A mirror outage means instances that boot and never become ready.

**Recommendation:** golden AMI for anything that launches in groups or autoscales; converge-on-boot only for one-off or frequently changing hosts.

## How it fits together

- terraform/main.tf builds two t3.micro instances tagged Lab=lab6, Role=web, with the existing LabInstanceProfile attached (attached, not created: IAM writes are denied in Academy) and a security group with port 80 only.
- ansible/inventory/lab6.aws_ec2.yml asks AWS for running instances tagged Lab=lab6 and groups them by the Role tag into role_web. No instance id or IP is written anywhere.
- ansible/group_vars/role_web.yml switches that group to the aws_ssm connection. The SSM connection stages files through an S3 bucket, and the bucket region and ansible_aws_ssm_region must be the same (us-east-1), otherwise the first task fails.
- ansible/roles/webserver holds the tasks, a handler for the restart, defaults (so Packer can override build_tag), and two Jinja2 templates.
- packer/web.pkr.hcl runs the same role on a throwaway build instance and saves an AMI. Packer reached that instance with its own per-build key pair and a temporary security group allowing port 22, both deleted when the build finished; that is the second sanctioned mechanism (ephemeral, never stored).

Changes from the walkthrough:
- The workflow runs terraform destroy after the converge step. A GitHub runner keeps no Terraform state, so without it every apply=true run would leave two instances and a security group running with nothing to delete them. The converge step is still the step immediately after apply.
- I ran the workflow after destroying my workstation's copy, because both use the same security group name.

## Experiments

### 4 - Make the inventory shrink
Predicted: with one of the two instances stopped, the graph would show one host.
Saw: @role_web listed only the running instance. The instance-state-name: running filter dropped the stopped one, so nobody edited a host list and Ansible never tried to connect to a machine that could not answer.

### 5 - Break the SSM connection with the wrong region
Predicted: setting ansible_aws_ssm_region to us-west-2 while the instances and bucket are in us-east-1 would fail with a region error.
Saw: the ping failed with TargetNotConnected "i-... is not connected", which looks like the instance is down. It wasn't: SSM was looking for it in us-west-2, where it doesn't exist. The message never mentions a region, so this failure has to be inferred. The aws_ssm connection plugin comes from the community.aws collection.

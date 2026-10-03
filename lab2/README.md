
# Lab 2

Instructions for this section will be provided in class and on Blackboard when we reach it.


# Setup
From my workstation I:
1. Created the key pair acs730-lab2-key and kept the .pem out of the repo.
2. Created the security group acs730-lab2-sg in the default VPC.
3. Added two inbound rules: SSH (22) from my workstation's /32 and HTTP (80) from 0.0.0.0/0.
4. Launched an AL2023 t3.micro with that key and security group.

On the instance I created acs730admin, my admin user with sudo, and did the
rest of the work as that user.

## Deployment steps
I ran deploy-web.sh as acs730admin. It:
1. Installed python3 with dnf.
2. Created the no-login service user acs730web.
3. Created /opt/acs730-web with the page, owned by acs730web.
4. Installed acs730-web.service and ran daemon-reload.
5. Enabled and started the service.

I rebooted the instance without logging in, and curl still returned the page
(see evidence/).

## start vs enable
start runs the service now; enable makes it start at every boot.

## Security group
I allowed SSH only from my workstation's /32 because SSH gives full control.
I opened HTTP to 0.0.0.0/0 because a website must be public.

## Application user
I ran the app as acs730web (no login, not root), so a compromised app cannot
take over the server. I gave it CAP_NET_BIND_SERVICE so it can use port 80.

## Experiments

### 1. start without enable
Prediction: I expected the site to be down after a reboot, with status showing disabled.
Result: curl returned 000, and status showed "disabled" and "inactive (dead)".
Disabling removed the boot link, so nothing started the service. I re-enabled it after.

### 2. Drop the capability
Prediction: I expected the restart to fail with Permission denied on port 80.
Result: journalctl showed "PermissionError: [Errno 13] Permission denied".
Only root can bind ports below 1024, which is why web servers used to start
as root. The capability allows just that. I restored it after.

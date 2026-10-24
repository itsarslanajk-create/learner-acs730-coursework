# Lab 4: Containerising the app, then building it in a pipeline

## Build and run

    cd lab4
    docker build -t acs730-lab4:slim .
    docker run -d --name lab4 -p 8000:8000 acs730-lab4:slim
    curl http://localhost:8000/healthz      # {"status":"ok","version":"dev"}
    docker rm -f lab4

## Image size: naive vs shipped

| Image | Base image | Size | Rebuild after a one-line code change |
| --- | --- | --- | --- |
| naive (Dockerfile.naive) | python:latest | 1.15 GB | 5.3 s, pip install re-ran |
| slim (Dockerfile) | python:3.12-slim-bookworm | 130 MB | 1.4 s, pip install CACHED |

- **How much is the base image:** almost all of it. python:3.12-slim-bookworm is 124 MB, so my own layers add about 6 MB; python:latest ships a full Debian with a compiler toolchain, about 1.13 GB before my code. docker history shows my code layers are 392 B (naive COPY . .) and 282 B (slim COPY app.py); the pip layer is 17.8 MB naive vs 6.38 MB slim, the difference being pip's download cache, which --no-cache-dir keeps out.
- **Is the dependency layer CACHED on a code-only rebuild:** only in the slim image. The slim Dockerfile copies requirements.txt and installs before copying app.py, so a code change invalidates only the COPY app.py layer onward. The naive one runs COPY . . before pip install, so any code change invalidates the install layer and every dependency is reinstalled.
- **What .dockerignore kept out of the context:** .git, .github, __pycache__, *.pyc, .pytest_cache, evidence/ (screenshots), *.md and the Dockerfiles themselves, which is why the context sent to the daemon was under 1 kB. It was present for both builds, so the naive image also stayed free of these files; without it, COPY . . would have copied everything in the folder into the image.
- **Other naive faults:** it runs as root (whoami printed root), and python:latest is a moving tag, so the same Dockerfile builds different images over time. The shipped image runs as appuser (UID 10001), pins the base tag, and uses exec-form CMD so gunicorn is PID 1 and stops cleanly.

## Why GHCR, tagged by commit SHA

The image tag is sha- plus the first 12 characters of the commit it was built from. That tag points at one commit forever, so "which code is in the running image" always has an answer, and a rollback is redeploying an older tag. latest points at whatever was pushed last, so it says nothing about the code inside. GHCR is used because the pipeline already authenticates to it with the automatic, short-lived GITHUB_TOKEN; no long-lived registry password or cloud credential is stored anywhere.

## GitHub Actions vs AWS-native: recommendation

The AWS-native equivalent of this pipeline is CodePipeline for the job graph, CodeBuild for the runners, and ECR instead of GHCR.

- **Where the runner lives:** GitHub Actions runners are GitHub-hosted VMs, created fresh for each job; CodeBuild runners live inside the AWS account.
- **What credential each needs:** this pipeline needs only GITHUB_TOKEN, minted per run and scoped by permissions:. CodeBuild needs an IAM service role, and pushing to ECR needs IAM permissions on the repository.
- **What can be built in an Academy account:** IAM writes are denied, so I cannot create the service roles CodePipeline and CodeBuild require; I would be limited to the pre-made LabRole, if it is accepted at all.

**Recommendation:** GitHub Actions for this course and for a team whose code already lives on GitHub: no cloud credentials are needed to build and publish, and it works in an Academy account. AWS-native becomes the better choice when images must stay inside AWS (ECR next to ECS or EKS, private networking, IAM-based audit) and the team can create IAM roles.

## Experiments


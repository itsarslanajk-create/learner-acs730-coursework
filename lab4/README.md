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

## CI timings: baseline, cache miss, cache hit

Runs: baseline 40053890389 (no caches), cache miss 40054975315 (caches just added), cache hit 40055057767 (README-only change). The hit run's log shows "Cache restored from key: setup-python-...-pip-2c9ba5fb20a" for both Python versions and "importing cache manifest from gha" for the Docker build.

| Step | Baseline | Cache miss | Cache hit | Worth it? |
| --- | --- | --- | --- | --- |
| pip install (test 3.11 / 3.12) | 5 s / 3 s | 3 s / 2 s | 2 s / 1 s | Yes, marginally |
| docker build (build job) | 8 s (plain docker build) | 14 s + 2 s cache export | 10 s + 1 s cache export | No |
| Whole workflow, wall clock | 52 s | 63 s | 82 s | n/a (dominated by runner start-up) |

- **pip cache: worth it, marginally.** The install step dropped from 3-5 s to 1-2 s once the cache was restored. The gain is small because only three pinned packages are installed, but it costs nothing (one with: block) and grows with the dependency list. The key is the two requirements files, so it invalidates exactly when what gets installed changes.
- **Docker layer cache: not worth it for this image.** Even on a confirmed hit the build step took 10 s plus 1 s exporting the cache, versus 8 s for a plain docker build with no cache. The image is 130 MB with a 6 MB dependency layer, so there is little to save, while buildx has to start a builder and import and export the cache manifest over the network every run. The comparison is not perfectly like-for-like (baseline used plain docker build, the cached runs use buildx), which is part of the point: switching to buildx to get the cache has its own cost. It would pay off for an image with a slow dependency or compile step.
- **Whole workflow:** wall clock went up across the three runs (52 s, 63 s, 82 s) even though individual steps got faster. Each job waits for a fresh GitHub-hosted runner, and that queueing varies from run to run and is larger than anything either cache saves here, which is why the per-step numbers, not the total, are the evidence.

## Why a composite action for one piece and a reusable workflow for the other

- **Composite action (.github/actions/python-deps):** setting up Python, restoring the pip cache and installing dependencies are steps that must run on the same runner as the tests that use them, inside the test job, once per matrix cell. A composite action packages steps that run inside an existing job, so it is the right shape.
- **Reusable workflow (.github/workflows/docker-build.yml):** building and pushing the image is a whole job with its own runner and needs packages: write, which the test job must not have. A reusable workflow packages entire jobs with their own permissions, so the push permission lives only in that job. In lab4-ci.yml the calling job (image) is the only job that widens past contents: read; every other job inherits read-only.

## Experiments


### Experiment 1: invert the layer order

**Prediction:** if app.py is copied before requirements.txt and pip install, a one-word code change will invalidate the install layer, so the rebuild will reinstall every dependency and take several seconds instead of about one.

**Result:** with COPY app.py moved above the requirements lines (my copy also kept the original COPY app.py lower down, which does not change the result), a one-word edit to app.py re-ran RUN pip install and the rebuild took 5.0 s, against 1.4 s with the shipped Dockerfile where pip install showed CACHED. Only the base and WORKDIR layers were still CACHED.

**Why:** Docker reuses a layer only if that instruction and every instruction before it are unchanged. COPY app.py changes whenever the code changes, so whatever comes after it is rebuilt. Placing the rarely-changing dependency install before the frequently-changing source means every future code change costs one tiny COPY layer instead of a full reinstall.

### Experiment 2: delete the .dockerignore

**Prediction:** the build context will grow, but the slim image will not, because the slim Dockerfile copies two named files rather than the whole folder.

**Result:** without .dockerignore the slim build transferred a 470 B context, the image stayed at 130 MB, and ls -a /app showed only app.py and requirements.txt. The .dockerignore was restored afterwards.

**Why:** the slim Dockerfile uses COPY requirements.txt and COPY app.py, so only those two files can reach the image whatever the context holds, and BuildKit transfers only the files the COPY lines need. The naive Dockerfile is different: COPY . . copies everything in the context, so without .dockerignore the screenshots in evidence/, the README, the tests and the Dockerfiles themselves would all be baked into the naive image. .dockerignore protects against careless COPY . .; explicit COPY of named files protects regardless.

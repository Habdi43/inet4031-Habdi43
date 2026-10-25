# Week 7: Continuous Delivery

## What this does
The deploy-gate.yml workflow runs on every push to main using GitHub-hosted runners. It checks OpenTofu formatting and validation and renders the Prometheus chart.

week-7/deploy.sh checks for a new commit on origin/main and deploys only if the gate passed for that exact commit. It runs tofu apply and helm upgrade --install.

Cron runs the script every two minutes. The VM connects out to GitHub. After a shutdown, it catches up when the network and cluster are ready.

The guard refuses deployment if the working copy is on another branch, has uncommitted tracked changes, or has commits not on origin/main. A lock prevents overlapping deployments.

The repository is public. No GitHub workflow runs on the VM, and credentials and state stay on the VM.

## Requirements
- The Week 5 app and Week 6 Prometheus on the k3d cluster
- OpenTofu, Helm, kubectl, and authenticated gh
- Active cron service and the schedule below

## Deploy
Merge a pull request into main and wait for the gate and cron.
To run immediately:
```bash
./week-7/deploy.sh
```

## Roll back
Create a branch, revert the relevant merge, open a pull request, and merge it:
```bash
git revert -m 1 <merge-commit>
```
Reverting configuration does not restore database contents or lost Prometheus history.

## Check status
```bash
crontab -l
tail -n 20 ~/deploy.log
gh run list --workflow deploy-gate.yml --limit 3
```

## Rebuild on a fresh VM
1. Recreate the Docker/k3d cluster and install OpenTofu, Helm, kubectl, and gh using the earlier labs.
2. Run gh auth login and configure kubectl for the cluster.
3. Clone this repository and check out main.
4. Copy week-5/terraform.tfvars.example to week-5/terraform.tfvars and fill in real values.
5. Build and import the week-4-web image as in Week 4.
6. Restore or initialize OpenTofu state appropriately for the target cluster.
7. Run ./week-7/deploy.sh.
8. Enable cron and add this schedule once from the repository root:
```bash
sudo systemctl enable --now cron
( crontab -l 2>/dev/null; echo "*/2 * * * * $PWD/week-7/deploy.sh >> $HOME/deploy.log 2>&1" ) | crontab -
```

The cron schedule, ~/.deployed-commit, variable values, and local OpenTofu state must be recreated or restored on a new VM.

## Known limitations
Deployment runs as my user from a folder I also edit. State and variable values live on one VM. There is no human approval before apply. The gate only catches problems covered by its checks. Prometheus uses temporary storage.

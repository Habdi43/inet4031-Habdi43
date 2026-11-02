# Week 8, Security Hardening and Shifting Left

## What this does
- Runs web as user 10001 with no privilege escalation and all capabilities dropped.
- Sets CPU and memory requests and limits for web and db.
- Uses a NetworkPolicy to allow only pods labeled app=web to reach db.
- Runs formatting, validation, chart rendering, and security checks on pull requests.
- Requires passing checks before merging into main.
- Blocks deployment plans that delete or replace resources.
- Keeps state files and deploy logs private.

## What lives where
| Where | What | Survives deleting the VM? |
| --- | --- | --- |
| GitHub | Ruleset and workflow configuration | Yes |
| Repository | OpenTofu files, deploy script, and ruleset.json | Yes, when pushed |
| VM | File permissions and cron | No |

## Rebuild the VM side
After completing the Week 7 rebuild steps:
```bash
chmod 600 week-5/terraform.tfstate* ~/deploy.log ~/.deployed-commit
chmod g-w,o-rwx ~
```

Recreate the ruleset only if it is missing:
```bash
gh api --method POST repos/{owner}/{repo}/rulesets --input week-8/ruleset.json
```

## Check on it
```bash
kubectl exec deploy/web -- id
kubectl get networkpolicy
gh api repos/{owner}/{repo}/rulesets
grep BLOCKED ~/deploy.log | tail -n 3
```

## Approving a destructive change
The deploy script saves and checks a plan before applying it.
If it would delete or replace resources, deployment stops.
Review the plan in week-5. Only approve an intended destructive change
by running tofu apply manually. For this lab, the rename was reverted.

## Known limitations
SSH still accepts passwords, and there is no host firewall.
State files contain plaintext secrets protected by file permissions.
The cron job runs as my user. Web can write to its filesystem,
and db runs as root. The scanner checks only six rules in week-5.
Repository administrators can delete the ruleset.

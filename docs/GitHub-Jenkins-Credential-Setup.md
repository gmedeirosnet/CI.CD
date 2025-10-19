# GitHub Jenkins Credential Setup for ArgoCD GitOps

## Overview
This guide shows how to create a GitHub Personal Access Token (PAT) and configure it in Jenkins so the pipeline can push Helm chart updates for ArgoCD to sync.

---

## Step 1: Create GitHub Personal Access Token

### 1.1 Navigate to GitHub Token Settings
1. Go to GitHub: https://github.com
2. Click your profile picture (top-right) → **Settings**
3. Scroll down to **Developer settings** (bottom of left sidebar)
4. Click **Personal access tokens** → **Tokens (classic)**
5. Click **Generate new token** → **Generate new token (classic)**

### 1.2 Configure Token
Fill in the following:

| Field | Value |
|-------|-------|
| **Note** | Jenkins CI/CD Pipeline |
| **Expiration** | 90 days (or as per your security policy) |
| **Select scopes** | Check the following: |
| ☑️ | **repo** (full control of private repositories) |
| ☑️ | **workflow** (update GitHub Action workflows - optional) |

### 1.3 Generate and Copy Token
1. Click **Generate token** at the bottom
2. **IMPORTANT:** Copy the token immediately - it won't be shown again!
3. Token format: `ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`

---

## Step 2: Add Credential to Jenkins

### 2.1 Navigate to Jenkins Credentials
1. Open Jenkins: http://localhost:8080
2. Go to: **Manage Jenkins** → **Credentials** → **System**
3. Click **Global credentials (unrestricted)**
4. Click **Add Credentials**

### 2.2 Configure Credential

| Field | Value |
|-------|-------|
| **Kind** | Username with password |
| **Scope** | Global |
| **Username** | `gmedeirosnet` (your GitHub username) |
| **Password** | `ghp_xxxx...` (paste the GitHub PAT token) |
| **ID** | `github-credentials` |
| **Description** | GitHub token for CI/CD pipeline commits |

### 2.3 Save
Click **Create**

---

## Step 3: Verify Jenkinsfile Configuration

Your `Jenkinsfile` should use the credential in the "Update Helm Chart" stage:

```groovy
stage('Update Helm Chart') {
    steps {
        script {
            // Update values.yaml with new image tag
            sh """
                cd helm-charts/cicd-demo
                sed -i 's/tag: .*/tag: "${IMAGE_TAG}"/' values.yaml
                cat values.yaml | grep tag:
            """

            // Commit and push using GitHub credentials
            withCredentials([usernamePassword(
                credentialsId: 'github-credentials',
                usernameVariable: 'GIT_USERNAME',
                passwordVariable: 'GIT_TOKEN'
            )]) {
                sh """
                    git config user.email "jenkins@cicd.local"
                    git config user.name "Jenkins CI"

                    cd helm-charts/cicd-demo
                    git add values.yaml
                    git diff --cached --quiet || git commit -m "ci: Update image tag to ${IMAGE_TAG} [skip ci]"

                    git push https://\${GIT_USERNAME}:\${GIT_TOKEN}@github.com/gmedeirosnet/CI.CD.git HEAD:main || echo "No changes to push"
                """
            }
        }
    }
}
```

---

## Step 4: Test the Credential

### 4.1 Manual Test (Optional)
Before running the full pipeline, test the credential:

```bash
# Replace with your actual token
export GIT_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxx"
export GIT_USERNAME="gmedeirosnet"

# Test clone
git clone https://${GIT_USERNAME}:${GIT_TOKEN}@github.com/gmedeirosnet/CI.CD.git test-clone

# Test push
cd test-clone
echo "test" >> README.md
git add README.md
git commit -m "test commit"
git push https://${GIT_USERNAME}:${GIT_TOKEN}@github.com/gmedeirosnet/CI.CD.git HEAD:main

# Cleanup
cd ..
rm -rf test-clone
```

### 4.2 Run Pipeline
1. Go to your Jenkins job
2. Click **Build Now**
3. Monitor the "Update Helm Chart" stage
4. Verify the commit appears in GitHub

---

## How the GitOps Flow Works

```
┌─────────────┐
│   Jenkins   │
│   Pipeline  │
└──────┬──────┘
       │
       │ 1. Build & Push Docker Image
       │
       ▼
┌─────────────┐
│   Harbor    │
│  Registry   │
└─────────────┘
       │
       │ 2. Update values.yaml
       │    with new image tag
       ▼
┌─────────────┐
│    Git      │
│   Commit    │──┐
└─────────────┘  │
                 │ 3. ArgoCD detects change
                 │
                 ▼
          ┌─────────────┐
          │   ArgoCD    │
          │             │
          └──────┬──────┘
                 │
                 │ 4. Deploy to K8s
                 │
                 ▼
          ┌─────────────┐
          │ Kubernetes  │
          │   Cluster   │
          └─────────────┘
```

---

## Troubleshooting

### Authentication Failed (403/401)
**Symptoms:** `fatal: Authentication failed` or `403 Forbidden`

**Solutions:**
1. Verify GitHub token has `repo` scope
2. Check token hasn't expired
3. Ensure username is correct in Jenkins credential
4. Test token manually: `curl -H "Authorization: token YOUR_TOKEN" https://api.github.com/user`

### Permission Denied (Push)
**Symptoms:** `Permission to gmedeirosnet/CI.CD.git denied`

**Solutions:**
1. Verify you're the owner or have write access to the repository
2. Check if branch is protected (may need to allow force push or disable protection)
3. Ensure token has `repo` scope (not just `public_repo`)

### Credential Not Found
**Symptoms:** `could not find credentials matching github-credentials`

**Solutions:**
1. Verify credential ID exactly matches: `github-credentials`
2. Check credential is in **Global** scope (not User scope)
3. Restart Jenkins if credential was just added

### Commit but No Push
**Symptoms:** Commit succeeds but push fails silently

**Solutions:**
1. Check Jenkins console output for error messages
2. Verify network connectivity from Jenkins to GitHub
3. Check if workspace is in detached HEAD state (pipeline should use `git push ... HEAD:main`)

### ArgoCD Not Syncing
**Symptoms:** Commit appears in GitHub but deployment doesn't update

**Solutions:**
1. Check ArgoCD app sync policy: `argocd app get cicd-demo`
2. Verify ArgoCD is watching the correct repository and path
3. Manually trigger sync: `argocd app sync cicd-demo`
4. Check ArgoCD logs: `kubectl logs -n argocd deployment/argocd-repo-server`

---

## Security Best Practices

### Token Security
- ✅ Use tokens with minimum required scopes
- ✅ Set expiration dates (90 days recommended)
- ✅ Rotate tokens regularly
- ✅ Never commit tokens to code
- ✅ Use Jenkins credentials (encrypted storage)

### Git Commits
- ✅ Use `[skip ci]` in commit messages to prevent infinite loops
- ✅ Use service account email (e.g., `jenkins@cicd.local`)
- ✅ Include meaningful commit messages with build numbers

### Repository Access
- ✅ Use fine-grained PAT tokens (classic PAT shown above, but fine-grained are better)
- ✅ Limit token to specific repositories if possible
- ✅ Use branch protection rules on main/production branches

---

## Alternative: SSH Keys (Advanced)

If you prefer SSH over HTTPS:

### 1. Generate SSH Key in Jenkins
```bash
# Inside Jenkins container
ssh-keygen -t ed25519 -C "jenkins@cicd.local" -f /var/jenkins_home/.ssh/id_ed25519 -N ""
cat /var/jenkins_home/.ssh/id_ed25519.pub
```

### 2. Add to GitHub
1. Copy the public key
2. GitHub → Settings → SSH and GPG keys → New SSH key
3. Paste the public key

### 3. Update Jenkinsfile
```groovy
// Use SSH URL
git push git@github.com:gmedeirosnet/CI.CD.git HEAD:main
```

### 4. Use SSH Agent Credential in Jenkins
- Kind: SSH Username with private key
- Private key: paste the private key from Jenkins container

---

## Next Steps

After completing this setup:

1. ✅ GitHub PAT created with `repo` scope
2. ✅ Jenkins credential `github-credentials` configured
3. ✅ Jenkinsfile updated to use the credential
4. 🔄 Run pipeline and verify commits appear in GitHub
5. 🔄 Verify ArgoCD detects changes and syncs
6. 🔄 Check application updates in Kubernetes

## Verification Checklist

- [ ] GitHub PAT created and copied
- [ ] Jenkins credential `github-credentials` added
- [ ] Pipeline runs without authentication errors
- [ ] Git commits appear in GitHub repository
- [ ] ArgoCD detects and syncs changes
- [ ] Application deployed successfully in Kubernetes
- [ ] Image tag in values.yaml matches build number

# Docker Permission Workaround - Quick Reference

## 🚨 Issue
Setup script fails on fresh remote nodes with:
```
Cannot connect to the Docker daemon at unix:///var/run/docker.sock. Is the docker daemon running?
```

## ✅ Solution
**Run the setup script twice:**

```bash
# First run (may fail at Step 4)
sudo ./k8s/scripts/setup-complete-kubernetes.sh

# Second run (will work)
sudo ./k8s/scripts/setup-complete-kubernetes.sh
```

## 🔍 Why This Happens
1. Docker gets installed and daemon starts successfully
2. User gets added to `docker` group
3. **Current shell session doesn't inherit the new group membership**
4. Permission denied on `/var/run/docker.sock`
5. Second run works because new shell session has proper group membership

## 🛠️ Alternative Manual Fixes
If you prefer not to run the script twice:

```bash
# Method 1: Restart shell session
exit
# Reconnect to server
sudo ./k8s/scripts/setup-complete-kubernetes.sh

# Method 2: Activate docker group
newgrp docker
sudo ./k8s/scripts/setup-complete-kubernetes.sh

# Method 3: Use sudo for Docker
sudo chmod 666 /var/run/docker.sock
sudo ./k8s/scripts/setup-complete-kubernetes.sh
sudo chmod 660 /var/run/docker.sock
```

## 📋 Status
- **Issue**: Known Docker permission problem on fresh nodes
- **Workaround**: Run script twice (recommended)
- **Permanent Fix**: In development for future versions
- **Impact**: Minor inconvenience, no data loss or corruption

## 🎯 Quick Test
To verify the workaround works:
```bash
# Test Docker access
docker ps

# If it fails, run the workaround
sudo ./k8s/scripts/setup-complete-kubernetes.sh
# Then run again
sudo ./k8s/scripts/setup-complete-kubernetes.sh
``` 
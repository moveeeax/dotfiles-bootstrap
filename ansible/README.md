# Ansible layer

Reproducible package installs for the dev environment.

```bash
# Install Ansible (once):
#   Debian/Ubuntu: sudo apt-get install -y ansible
#   Fedora/RHEL:   sudo dnf install -y ansible
#   macOS:         brew install ansible

# Dry run — show what would change:
ansible-playbook -i inventory.ini playbook.yml --check

# Apply:
ansible-playbook -i inventory.ini playbook.yml
```

- The toolset lives in [`group_vars/all.yml`](group_vars/all.yml) — edit that list, not the play.
- `playbook.yml` picks the right package module per OS family (apt / dnf / pacman).
- The play is idempotent: re-running is a no-op for packages already present.

`./bootstrap.sh --packages` runs exactly this playbook for you.

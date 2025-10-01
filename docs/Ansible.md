# Ansible Guide

## Introduction
Ansible is an open-source automation tool for configuration management, application deployment, and task automation. It uses a simple, agentless architecture and human-readable YAML syntax.

## Key Features
- Agentless architecture (uses SSH)
- Simple YAML syntax (Playbooks)
- Idempotent operations
- Large module library (3000+ modules)
- Strong community support
- Parallel execution across multiple hosts
- Integration with cloud providers and container platforms
- Role-based organization

## Prerequisites
- Linux/Unix system (control node)
- Python 3.8+ installed
- SSH access to managed nodes
- Basic understanding of YAML syntax

## Installation

### On macOS
```bash
brew install ansible
```

### On Linux (Ubuntu/Debian)
```bash
sudo apt update
sudo apt install ansible
```

### Using pip
```bash
pip install ansible
```

### Verify Installation
```bash
ansible --version
```

## Basic Concepts

### Inventory
Define managed hosts in an inventory file:

```ini
# inventory.ini
[webservers]
web1.example.com
web2.example.com

[databases]
db1.example.com

[all:vars]
ansible_user=admin
ansible_ssh_private_key_file=~/.ssh/id_rsa
```

### Playbooks
Playbooks are YAML files that define automation tasks:

```yaml
# playbook.yml
---
- name: Configure web servers
  hosts: webservers
  become: yes
  tasks:
    - name: Install nginx
      apt:
        name: nginx
        state: present
        update_cache: yes

    - name: Start nginx service
      service:
        name: nginx
        state: started
        enabled: yes

    - name: Copy configuration file
      copy:
        src: nginx.conf
        dest: /etc/nginx/nginx.conf
        owner: root
        group: root
        mode: '0644'
      notify: Restart nginx

  handlers:
    - name: Restart nginx
      service:
        name: nginx
        state: restarted
```

### Roles
Organize playbooks into reusable roles:

```bash
ansible-galaxy init myrole
```

Structure:
```
myrole/
├── defaults/       # Default variables
├── files/          # Static files
├── handlers/       # Handlers
├── meta/           # Role metadata
├── tasks/          # Main task list
├── templates/      # Jinja2 templates
├── tests/          # Test playbooks
└── vars/           # Other variables
```

## Basic Usage

### Ad-hoc Commands
```bash
# Ping all hosts
ansible all -m ping -i inventory.ini

# Run shell command
ansible webservers -a "uptime" -i inventory.ini

# Install package
ansible webservers -m apt -a "name=vim state=present" -b -i inventory.ini

# Copy file
ansible all -m copy -a "src=/etc/hosts dest=/tmp/hosts" -i inventory.ini
```

### Running Playbooks
```bash
# Run playbook
ansible-playbook playbook.yml -i inventory.ini

# Check mode (dry run)
ansible-playbook playbook.yml -i inventory.ini --check

# Verbose output
ansible-playbook playbook.yml -i inventory.ini -vvv

# Limit to specific hosts
ansible-playbook playbook.yml -i inventory.ini --limit web1.example.com

# Use tags
ansible-playbook playbook.yml -i inventory.ini --tags "configuration"
```

## Advanced Features

### Variables
```yaml
# group_vars/webservers.yml
nginx_port: 80
nginx_user: www-data

# Using variables in playbook
- name: Configure nginx
  template:
    src: nginx.conf.j2
    dest: /etc/nginx/nginx.conf
```

### Templates (Jinja2)
```jinja2
# templates/nginx.conf.j2
user {{ nginx_user }};
worker_processes auto;

http {
    server {
        listen {{ nginx_port }};
        server_name {{ ansible_hostname }};
    }
}
```

### Conditionals
```yaml
- name: Install package on Debian
  apt:
    name: apache2
    state: present
  when: ansible_os_family == "Debian"

- name: Install package on RedHat
  yum:
    name: httpd
    state: present
  when: ansible_os_family == "RedHat"
```

### Loops
```yaml
- name: Install multiple packages
  apt:
    name: "{{ item }}"
    state: present
  loop:
    - nginx
    - git
    - vim
```

### Vault (Encrypted Variables)
```bash
# Create encrypted file
ansible-vault create secrets.yml

# Edit encrypted file
ansible-vault edit secrets.yml

# Run playbook with vault
ansible-playbook playbook.yml --ask-vault-pass
```

## Integration with Other Tools

### Docker Integration
```yaml
- name: Deploy Docker container
  docker_container:
    name: myapp
    image: myapp:latest
    state: started
    ports:
      - "8080:8080"
```

### Kubernetes Integration
```yaml
- name: Deploy to Kubernetes
  k8s:
    state: present
    definition:
      apiVersion: v1
      kind: Pod
      metadata:
        name: myapp
      spec:
        containers:
        - name: myapp
          image: myapp:latest
```

### AWS Integration
```yaml
- name: Create EC2 instance
  ec2:
    key_name: mykey
    instance_type: t2.micro
    image: ami-12345678
    wait: yes
    region: us-east-1
    count: 1
```

### Jenkins Integration
- Use Ansible plugin in Jenkins
- Execute Ansible playbooks from Jenkins pipeline
- Dynamic inventory from Jenkins parameters

## Best Practices
1. Use roles to organize complex playbooks
2. Keep playbooks idempotent
3. Use version control for all Ansible code
4. Store sensitive data in Ansible Vault
5. Use dynamic inventory for cloud environments
6. Tag tasks for selective execution
7. Write descriptive task names
8. Use check mode before applying changes
9. Implement error handling with blocks
10. Document variables and their purposes

## Common Use Cases

### Configuration Management
```yaml
- name: Standardize server configuration
  hosts: all
  tasks:
    - name: Set timezone
      timezone:
        name: America/New_York

    - name: Configure NTP
      package:
        name: ntp
        state: present
```

### Application Deployment
```yaml
- name: Deploy application
  hosts: appservers
  tasks:
    - name: Pull latest code
      git:
        repo: https://github.com/example/app.git
        dest: /opt/app
        version: main

    - name: Install dependencies
      pip:
        requirements: /opt/app/requirements.txt

    - name: Restart application
      systemd:
        name: myapp
        state: restarted
```

### Infrastructure Provisioning
```yaml
- name: Provision AWS infrastructure
  hosts: localhost
  tasks:
    - name: Create VPC
      ec2_vpc_net:
        name: my-vpc
        cidr_block: 10.0.0.0/16
        region: us-east-1
```

## Troubleshooting

### Connection Issues
```bash
# Test connectivity
ansible all -m ping -i inventory.ini

# Check SSH configuration
ansible all -m setup -i inventory.ini

# Use verbose mode
ansible-playbook playbook.yml -vvvv
```

### Common Errors
- Host key verification failed: Use `ansible_ssh_common_args: '-o StrictHostKeyChecking=no'`
- Permission denied: Check SSH keys and user permissions
- Module not found: Ensure Python is installed on target hosts
- Playbook syntax errors: Use `ansible-playbook --syntax-check playbook.yml`

## Performance Optimization
1. Use pipelining: `pipelining = True` in ansible.cfg
2. Increase parallelism: `forks = 50`
3. Use async tasks for long-running operations
4. Disable fact gathering when not needed: `gather_facts: no`
5. Use mitogen strategy plugin for faster execution

## References
- Official Documentation: https://docs.ansible.com/
- Ansible Galaxy: https://galaxy.ansible.com/
- GitHub Repository: https://github.com/ansible/ansible
- Best Practices: https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html

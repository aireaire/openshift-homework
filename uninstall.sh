#!/usr/bin/bash
OPENSHIFT_ANSIBLE_PATH=/usr/share/ansible/openshift-ansible

ansible-playbook "$OPENSHIFT_ANSIBLE_PATH/playbooks/adhoc/uninstall.yml"
ansible nodes -a "rm -rf /etc/origin"
ansible nfs -a "rm -rf /srv/nfs/*"

#!/usr/bin/bash

OPENSHIFT_ANSIBLE_PATH=/usr/share/ansible/openshift-ansible

usage()
{
  echo "Usage: $0 -g GUID -u OREG_USER -p OREG_PASS"
  exit 2
}

set_variable()
{
  local varname=$1
  shift
  if [ -z "${!varname}" ]; then
    eval "$varname=\"$@\""
  else
    echo "Error: $varname already set"
    usage
  fi
}

#########################
# Main script starts here

unset MY_GUID ACTION

while getopts 'g:p:u:r?h' c
do
  case $c in
    r) set_variable ACTION REINSTALL ;;
    u) set_variable OREG_USER $OPTARG ;;
    p) set_variable OREG_PASS $OPTARG ;;
    g) set_variable MY_GUID $OPTARG ;;
    h|?) usage ;; esac
done

[ -z "$MY_GUID" ] && usage
if [ -z "$OREG_USER"]; then
    usage
else
    echo "Supplied user for registry authentication: $OREG_USER"
fi

if [ -z "$OREG_PASS" ]; then
    usage
fi

echo "Updating hosts file with GUID=$MY_GUID"
sed "s/\${GUID}/$MY_GUID/" hosts.template > hosts

echo "Backup /etc/ansible/hosts"
cp -n /etc/ansible/hosts /etc/ansible/hosts-$(date +%F).bkp
echo "Copy generated hosts to /etc/ansible"
cp -f hosts /etc/ansible/hosts
echo "Copy group_vars/OSEv3.yaml to /etc/ansible/group_vars"
mkdir -p /etc/ansible/group_vars
cp -f group_vars/OSEv3.yaml /etc/ansible/group_vars

echo "Export GUID"
#ansible localhost,all -m shell -a 'export GUID=`hostname | cut -d"." -f2`; echo "export GUID=$GUID" >> $HOME/.bashrc'
export GUID=$MY_GUID

if [ "$ACTION" == "REINSTALL" ]; then
    ansible-playbook "$OPENSHIFT_ANSIBLE_PATH/playbooks/adhoc/uninstall.yml"
    ansible nodes -a "rm -rf /etc/origin"
    ansible nfs -a "rm -rf /srv/nfs/*"
fi

ansible-playbook "$OPENSHIFT_ANSIBLE_PATH/playbooks/prerequisites.yml" \
--extra-vars "OREG_AUTH_USER=$OREG_USER OREG_AUTH_PASS=$OREG_PASS" \
&& ansible-playbook "$OPENSHIFT_ANSIBLE_PATH/playbooks/deploy_cluster.yml" \
--extra-vars "OREG_AUTH_USER=$OREG_USER OREG_AUTH_PASS=$OREG_PASS" \
&& ansible masters[0] -b -m fetch -a "src=/root/.kube/config dest=/root/.kube/config flat=yes"


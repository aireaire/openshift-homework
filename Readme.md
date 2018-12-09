[WIP] Homework Assignment
===================
This is a documentation for homework assignment for ocp_advanced_deployment by Aleksandrs Sins

To deploy the cluster run ./install.sh script providing mandatory parameters:

```
./install.sh -g <GUID>
```

The script deploys OpenShift cluster in Red Hat's lab environment assuming that the following nodes have been provisioned by infrastructure:

**loadbalancer node**
- `loadbalancer1.$GUID.internal`

**masters**
- `master1.$GUID.internal`
- `master2.$GUID.internal`
- `master3.$GUID.internal`


**infra nodes**
- `infranode1.$GUID.internal`
- `infranode2.$GUID.internal`


**regular nodes**
- `node1.$GUID.internal`
- `node2.$GUID.internal`
- `node3.$GUID.internal`
- `node4.$GUID.internal`


**storage node**
- `support1.$GUID.internal`


## Basic requirements

- ### Ability to authenticate at the master console
The installation script for POC OpenShift cluster for MitziCom creates pre-defined users from httpasswd.openshift file. This is configured by the following group variables in `/etc/ansible/group_vars/OSEv3.yaml`:
```yaml
openshift_master_identity_providers: [{'name': 'htpasswd_auth', 'login': 'true', 'challenge': 'true', 'kind': 'HTPasswdPasswordIdentityProvider'}]
openshift_master_htpasswd_file: /root/htpasswd.openshift
```
Refer to [Configuring authentication and user agent](https://docs.openshift.com/container-platform/3.11/install_config/configuring_authentication.html) documentation if you want to use other identity provider.

- ### Registry has storage attached and working


## HA requirements

## Environment configuration

## CICD Workflow

## Multitenancy
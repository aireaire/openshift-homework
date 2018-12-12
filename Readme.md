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
In order to authenticate to openshift at the master console, first login to master host, e.g. master1.GUID.internal, and then use following command:
```
oc login -u USER -p PASSWORD
```
You may omit -u and -p parameters. In that case user name and password will be prompted interactively.

Infromation about how users are added at deployment time can be found in [master configuration](#there-are-three-masters-working) section.

- ### Registry has storage attached and working
Registry storage of type NFS is located on the support node **support1.GUID.internal** in `/srv/nfs/registry folder`


Following group variables configure storage:
```yaml
openshift_hosted_registry_storage_kind: nfs
openshift_hosted_registry_storage_access_modes: ['ReadWriteMany']
openshift_hosted_registry_storage_nfs_directory: /srv/nfs
openshift_hosted_registry_storage_nfs_options: '*(rw, root_squash)'
openshift_hosted_registry_storage_volume_name: registry
openshift_hosted_registry_storage_volume_size: 20Gi
```

- ### Router is configured on each infranode
By default node selector for router is set to `node-role.kubernetes.io/infra=true` label in `/usr/share/ansible/openshift-ansible/roles/openshift_hosted/defaults/main.yml`
```yaml
openshift_hosted_infra_selector: "node-role.kubernetes.io/infra=true"
...
openshift_hosted_router_selector: "{{ openshift_router_selector | default(openshift_hosted_infra_selector) }}"
openshift_hosted_router_namespace: 'default'
```

Infra nodes are defined by assigning them to `'node-config-infra'` node group in the inventory file, e.g.:
```ini
[nodes]
infranode1.80f0.internal openshift_node_group_name='node-config-infra'
infranode2.80f0.internal openshift_node_group_name='node-config-infra'
```

The default label `node-role.kubernetes.io/infra=true` for `'node-config-infra'` node group is defined in `/usr/share/ansible/openshift-ansible/roles/openshift_facts/defaults/main.yml` file.

For more details see [configuring inventory node group definitions](https://docs.openshift.com/container-platform/3.10/install/configuring_inventory_file.html#configuring-inventory-node-group-definitions) documentation.
- ### PVs of different types are available for users to consume


- ### Ability to deploy a simple app (**nodejs-mongo-persistent**)

## HA requirements
- ### There are three masters working
To configure master nodes in the openshift cluster create `masters` group in the hosts inventory file.

The below example instructs ansible deployer to setup three master nodes:

```ini
[OSEv3:children]
...
masters

[masters]
master1.GUID.internal
master2.GUID.internal
master3.GUID.internal

[nodes]
## These are the masters
master1.GUID.internal openshift_node_group_name='node-config-master'
master2.GUID.internal openshift_node_group_name='node-config-master'
master3.GUID.internal openshift_node_group_name='node-config-master'
...
```

Also in the `group_vars/OSEv3.yaml` define variables to set up users for the OpneShift cluster:

```yaml
openshift_master_identity_providers: [{'name': 'htpasswd_auth', 'login': 'true', 'challenge': 'true', 'kind': 'HTPasswdPasswordIdentityProvider'}]
openshift_master_htpasswd_file: /root/htpasswd.openshift
```

Refer to [Configuring authentication and user agent](https://docs.openshift.com/container-platform/3.11/install_config/configuring_authentication.html) OpenShift documentation if you want to use other identity provider.


- ### There are three etcd instances working
Like with masters, for etcd instances one should create **etcd** group in the hosts inventory file. Use same nodes as in **masters** group for etcd instances.

```ini
[OSEv3:children]
...
etcd

[etcd]
master1.GUID.internal
master2.GUID.internal
master3.GUID.internal
```

- ### There is a load balancer to access the masters

- ### There is a load balancer/DNS for both infranodes

- ### There are at least two infranodes

## Environment configuration
- ### NetworkPolicy is configured and working with default project isolation (simulate Multitenancy)

- ### Aggregated logging is configured and working

- ### Metrics collection is configured and working

- ### Router and Registry Pods run on Infranodes

- ### Metrics and Logging components run on Infranodes

## CICD Workflow
- ### Jenkins pod is running with a persistent volume

- ### Jenkins deploys openshift-tasks app

- ### Jenkins OpenShift plugin is used to create a CICD workflow

- ### HPA is configured and working on production deployment of openshift-tasks

## Multitenancy
- ### Multiple clients/customers created

- ### Dedicated node for each client/customer

- ### admissionControl plugin sets specific limits per label (client/customer)

- ### The new project template is modified so that it includes a LimitRange

- ### The new user template is used to create a user object with the specific label value

- ### On-boarding new client documentation explains how to create a new client/customer

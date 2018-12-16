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
# file: group_vars/OSEv3.yaml

openshift_hosted_registry_storage_kind: nfs
openshift_hosted_registry_storage_access_modes: ['ReadWriteMany']
openshift_hosted_registry_storage_nfs_directory: /srv/nfs
openshift_hosted_registry_storage_nfs_options: '*(rw, root_squash)'
openshift_hosted_registry_storage_volume_name: registry
openshift_hosted_registry_storage_volume_size: 20Gi
```

- ### Router is configured on each infranode
Specify infranodes label in router node selector
```yaml
# file: group_vars/OSEv3.yaml

openshift_router_selector:
  "node-role.kubernetes.io/infra": "true"

# this also defines number of pods for router instances
openshift_hosted_router_replicas: 2
```

NOTE: If you're going to use default label for infra nodes as in the example above, you actually don't have to specify it, as it is set by OpenShift ansible deployer. See below:
```yaml
# file: /usr/share/ansible/openshift-ansible/roles/openshift_hosted/defaults/main.yml

openshift_hosted_infra_selector: "node-role.kubernetes.io/infra=true"
...
openshift_hosted_router_selector: "{{ openshift_router_selector | default(openshift_hosted_infra_selector) }}"
openshift_hosted_router_namespace: 'default'
```

- ### PVs of different types are available for users to consume


- ### Ability to deploy a simple app (**nodejs-mongo-persistent**)

## HA requirements
- ### There are three masters working
To configure master nodes in the openshift cluster create `masters` group in the hosts inventory file.

The below example instructs ansible deployer to setup three master nodes:

```ini
# file /etc/ansible/hosts

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

Also specify HTPasswd identity provider to import users for the cluster in group variables file `group_vars/OSEv3.yaml`:

```yaml
# file: group_vars/OSEv3.yaml

openshift_master_identity_providers: [{'name': 'htpasswd_auth', 'login': 'true', 'challenge': 'true', 'kind': 'HTPasswdPasswordIdentityProvider'}]
openshift_master_htpasswd_file: /root/htpasswd.openshift
```
More information on how to create your custom HTPasswd file or use different identity provider, e.g LDAP, see  [Configuring authentication and user agent](https://docs.openshift.com/container-platform/3.11/install_config/configuring_authentication.html) OpenShift documentation.

- ### There are three etcd instances working
Like with masters, for etcd instances create **etcd** group in the hosts inventory file. Use same nodes as for **masters** group.

```ini
# file /etc/ansible/hosts

[OSEv3:children]
...
etcd

[etcd]
master1.GUID.internal
master2.GUID.internal
master3.GUID.internal
```

- ### There is a load balancer to access the masters
To deploy a load balancer to access the masters define load balancer host in the **lb** group of the hosts inventory file.
```ini
# file /etc/ansible/hosts

[OSEv3:children]
...
lb

[lb]
loadbalancer1.GUID.internal
```

And define master ports and domain name for external load balancer access in `group_vars/OSEv3.yaml`:
```yaml
# file: group_vars/OSEv3.yaml

openshift_master_api_port: 443
openshift_master_console_port: 443

# load balancer domain name for external access
openshift_master_cluster_public_hostname: loadbalancer.GUID.example.opentlc.com
```

- ### There is a load balancer/DNS for both infranodes
Specify load balancer host for infra nodes in `group_vars/OSEv3.yaml`:
```yaml
# file: group_vars/OSEv3.yaml

# load balancer domain name for internal cluster communication
openshift_master_cluster_hostname: loadbalancer1.GUID.internal
```

- ### There are at least two infranodes
Infra nodes should be listed in **nodes** group and assigned to `'node-config-infra'` openshift node group in the inventory file, e.g.:
```ini
# file /etc/ansible/hosts

[nodes]
infranode1.80f0.internal openshift_node_group_name='node-config-infra'
infranode2.80f0.internal openshift_node_group_name='node-config-infra'
```

The openshift infra node group `'node-config-infra'` gets default label `node-role.kubernetes.io/infra=true` by ansible deployer. See `/usr/share/ansible/openshift-ansible/roles/openshift_facts/defaults/main.yml` file.

For more details see [configuring inventory node group definitions](https://docs.openshift.com/container-platform/3.10/install/configuring_inventory_file.html#configuring-inventory-node-group-definitions) documentation.

## Environment configuration
- ### NetworkPolicy is configured and working with default project isolation (simulate Multitenancy)
Specify network plugin for OpenShift SDN

```yaml
# file: group_vars/OSEv3.yaml

os_sdn_network_plugin_name: 'redhat/openshift-ovs-networkpolicy'
```

- ### Aggregated logging is configured and working
To enable logging specify following variables in `group_vars/OSEv3.yaml`

```yaml
# file: group_vars/OSEv3.yaml

# Enable logging
openshift_logging_install_logging: true
openshift_logging_install_eventrouter: true

# Define storage for logging
openshift_logging_storage_kind: nfs
openshift_logging_storage_access_modes: ['ReadWriteOnce']
openshift_logging_storage_nfs_directory: /srv/nfs
openshift_logging_storage_nfs_options: '*(rw,root_squash)'
openshift_logging_storage_volume_name: logging
openshift_logging_storage_volume_size: 10Gi
openshift_logging_storage_labels:
  "storage": "logging"
openshift_logging_es_pvc_storage_class_name: ''
openshift_logging_es_memory_limit: 8Gi
openshift_logging_es_cluster_size: 1

openshift_logging_curator_default_days: 2
```

Refer to OpenShift [Aggregate Logging](https://docs.openshift.com/container-platform/3.6/install_config/aggregate_logging.html) documentation for additional options.
- ### Metrics collection is configured and working
Specify following group varaibles in  `group_vars/OSEv3.yaml` for metrics:

```yaml
# file: group_vars/OSEv3.yaml

# Enable metrics
openshift_metrics_install_metrics: true

# Configure storage for metrics
openshift_metrics_storage_kind: nfs
openshift_metrics_storage_access_modes: ['ReadWriteOnce']
openshift_metrics_storage_nfs_directory: /srv/nfs
openshift_metrics_storage_nfs_options: '*(rw,root_squash)'
openshift_metrics_storage_volume_name: metrics
openshift_metrics_storage_volume_size: 10Gi
openshift_metrics_storage_labels:
  "storage": "metrics"
openshift_metrics_cassandra_pvc_storage_class_name: ""

# Store Metrics for 2 days
openshift_metrics_duration: 2
```
- ### Router and Registry Pods run on Infranodes
By default node selector for Router and Registry is set to 'node-role.kubernetes.io/infra=true'

You only need to change selectors if you have defined other labels for infra nodes
```yaml
# file: group_vars/OSEv3.yaml

openshift_router_selector:
    <your infra node label key>: <label value>
openshift_registry_selector:
    <your infra node label key>: <label value>
```
- ### Metrics and Logging components run on Infranodes
Specify node selectors for Metrics and Logging components in group varaibles in  `group_vars/OSEv3.yaml`

```yaml
# file: group_vars/OSEv3.yaml

# Configure where logging services will run
# Kibana
openshift_logging_kibana_nodeselector:
  "node-role.kubernetes.io/infra": "true"
# Curator
openshift_logging_curator_nodeselector:
  "node-role.kubernetes.io/infra": "true"
# ElasticSearch
openshift_logging_es_nodeselector:
  "node-role.kubernetes.io/infra": "true"
# Event Router
openshift_logging_eventrouter_nodeselector:
  "node-role.kubernetes.io/infra": "true"

# Configure where metrics services will run
# Hawkular
openshift_metrics_hawkular_nodeselector:
  "node-role.kubernetes.io/infra": "true"
# Cassandra
openshift_metrics_cassandra_nodeselector:
  "node-role.kubernetes.io/infra": "true"
# Heapster
openshift_metrics_heapster_nodeselector:
  "node-role.kubernetes.io/infra": "true"
```

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

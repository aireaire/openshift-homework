Advanced Deployment with OpenShift - Homework Assignment
=========================
> by Aleksandrs Sins

This is a homework documentation for ocp_advanced_deployment course. It is organized in the same way as
requirements are defined in the assignment and describes how the requirements were fulfilled.

## Installation
1. Login to your bastion host as root
2. Clone the repository
```bash
git clone https://github.com/aireaire/openshift-homework.git
```
3. Run `main.yml` ansible playbook providing 3 group variables from command line:
```bash
ansible-playbook main.yml --extra-vars="GUID=9519 OREG_AUTH_USER='yourusername' OREG_AUTH_PASS='yourpassword'"

```

* `GUID` - The ID of cluster provided by labs.opentlc.com for Homework Assignment.
* `OREG_AUTH_USER` - User name to authenticate to registry.access.redhat.com online registry.
* `OREG_AUTH_PASS` - Password to authenticate to registry.access.redhat.com online registry.

## Prerequisites
The playbook deploys OpenShift cluster in Red Hat's lab environment assuming that the following nodes have been provisioned by infrastructure:

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
Ansible playbook prepares bastion host to deploy OpenShift cluster with following steps:
1. Installs `atomic-openshift-clients` and `openshift-ansible` yum packages
2. Downloads `openshift-applier` role from https://github.com/redhat-cop/openshift-applier.git project

To deploy OpenShift cluster with Ansible deployer it creates inventory file from `templates/hosts.j2` template and
copies it to `/etc/ansible/hosts` file. The inventory describes `OSEv3` hosts super group according to prerequisites.

Group variables for OSEv3 are specified in `resources/OSEv3.yaml` file which is copied to /etc/ansible/group_vars/ folder.
See further sections for more details about OpenShift cluster deployment.

- #### Ability to authenticate at the master console
After successful playbook run you should be able to authenticate to openshift from master or bastion host with `oc` tool:
```
oc login -u USER -p PASSWORD
```
You may also omit -u and -p parameters, then user name and password will be prompted interactively.

Infromation about how users are added at deployment time can be found in [master configuration](#there-are-three-masters-working) section.

- #### Registry has storage attached and working
Registry storage of type NFS is located on the support node **support1.GUID.internal** in `/srv/nfs/registry` folder.

Following group variables specify registry storage parameters:
```yaml
# file: group_vars/OSEv3.yaml

# Set this line to enable NFS
# Note that NFS is used temporary as a POC. It is discouraged to use NFS and you should consider switching to different
# storage solution.
openshift_enable_unsupported_configurations: true

openshift_hosted_registry_storage_kind: nfs
openshift_hosted_registry_storage_access_modes: ['ReadWriteMany']
openshift_hosted_registry_storage_nfs_directory: /srv/nfs
openshift_hosted_registry_storage_nfs_options: '*(rw, root_squash)'
openshift_hosted_registry_storage_volume_name: registry
openshift_hosted_registry_storage_volume_size: 20Gi
```

- #### Router is configured on each infranode
Default label `"node-role.kubernetes.io/infra": "true"` for infra nodes is set in router node selector to ensure
router pods are scheduled on them.

NOTE: the OpenShift cluster POC for MitziCom is created with pre-defined users from httpasswd.openshift file. This is configured by the following group variables in `/etc/ansible/group_vars/OSEv3.yaml`:

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

- #### PVs of different types are available for users to consume
Persistent Volumes are created by post-installation configuration playbook `create_pvs.yaml` as follows:
- creates 200 folders in `/srv/nfs/user-vols/` directory on the `support1.GUID.internal` node.
- using openshift-applier, creates 25 PersistentVolume objects size of 5Gi in OpenShift cluster
- using openshift-applier, creates 25 PersistentVolume objects size of 10Gi in OpenShift cluster

For more details see `create_pvs.yaml` playbook and `templates/pv_template.yaml` template.

- #### Ability to deploy a simple app (**nodejs-mongo-persistent**)
To deploy sample app **nodejs-mongo_persistent** try run following commands on master node
```shell
oc new-project smoke-test
oc new-app nodejs-mongo-persistent
```

App deployment should start. To see the status of app check pods status
```shell
oc get pods -n smoke-test
```

Once application has been deployed successfully you should see following output
```
NAME                              READY     STATUS      RESTARTS   AGE
mongodb-1-qvv9n                   1/1       Running     0          2m
nodejs-mongo-persistent-1-build   0/1       Completed   0          2m
nodejs-mongo-persistent-1-g2cjd   1/1       Running     0          2m
```
## HA requirements
- #### There are three masters working
To configure master nodes in the openshift cluster create `masters` group in the hosts inventory file.

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

HTPasswd is used as identity provider and configured in following group variables:
```yaml
# file: group_vars/OSEv3.yaml

openshift_master_identity_providers: [{'name': 'htpasswd_auth', 'login': 'true', 'challenge': 'true', 'kind': 'HTPasswdPasswordIdentityProvider'}]
openshift_master_htpasswd_file: /root/htpasswd.openshift
```

More information on how to create your custom HTPasswd file or use different identity provider, e.g LDAP, see  [Configuring authentication and user agent](https://docs.openshift.com/container-platform/3.11/install_config/configuring_authentication.html) OpenShift documentation.

- #### There are three `**etcd**` instances working
Like with masters, for etcd instances create **etcd** group in the `/etc/ansible/hosts` inventory file and
reuse **masters** group nodes.

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

- #### There is a load balancer to access the masters
To deploy a load balancer for masters access the load balancer host is defined in the **lb** group of the inventory:
```ini
# file /etc/ansible/hosts

[OSEv3:children]
...
lb

[lb]
loadbalancer1.GUID.internal
```

Master ports and domain name for external load balancer access are configured as follows:
```yaml
# file: group_vars/OSEv3.yaml

openshift_master_api_port: 443
openshift_master_console_port: 443

# load balancer domain name for external access
openshift_master_cluster_public_hostname: loadbalancer.${GUID}.example.opentlc.com
```

- #### There is a load balancer/DNS for both infranodes called \*.apps.$GUID.$DOMAIN
The load balancer for infra nodes and any exposed application is configured as follows:
```yaml
# file: group_vars/OSEv3.yaml

# load balancer domain name for internal cluster communication
openshift_master_cluster_hostname: loadbalancer1.${GUID}.internal
openshift_master_default_subdomain: apps.${GUID}.example.opentlc.com
```

- #### There are at least two infranodes
Infra nodes are listed in **nodes** group and linked to `'node-config-infra'` openshift node group in the inventory file
as follows:
```ini
# file /etc/ansible/hosts

[nodes]
infranode1.${GUID}.internal openshift_node_group_name='node-config-infra'
infranode2.${GUID}.internal openshift_node_group_name='node-config-infra'
```

The openshift infra node group `'node-config-infra'` is assigned the default label `node-role.kubernetes.io/infra=true`
in Ansible deployer. Check `/usr/share/ansible/openshift-ansible/roles/openshift_facts/defaults/main.yml` file.

For more details see [configuring inventory node group definitions](https://docs.openshift.com/container-platform/3.10/install/configuring_inventory_file.html#configuring-inventory-node-group-definitions) documentation.

## Environment configuration
- #### NetworkPolicy is configured and working with projects isolated by default
Network Policy plugin for OpenShift SDN is configured as follows:
```yaml
# file: group_vars/OSEv3.yaml

os_sdn_network_plugin_name: 'redhat/openshift-ovs-networkpolicy'
```

- #### Aggregated logging is configured and working
To enable logging and setup storage for it following variables are set:
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

For additional options refer to OpenShift [Aggregate Logging](https://docs.openshift.com/container-platform/3.6/install_config/aggregate_logging.html) documentation.

- #### Metrics collection is configured and working
To enable projects metrics and setup storage for it following group varaibles are set:
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
- #### Router and Registry Pods run on Infranodes
By default node selector for Router and Registry is set to 'node-role.kubernetes.io/infra=true'

Change selectors only if you have defined other labels for infra nodes:
```yaml
# file: group_vars/OSEv3.yaml

openshift_router_selector:
    <your infra node label key>: <label value>
openshift_registry_selector:
    <your infra node label key>: <label value>
```
- #### Metrics and Logging components run on Infranodes
To enable Metrics and Logging components set following group varaibles:
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
The CICD workflow is configured by `cicd.yaml` playbook that uses templates in `resources/openshift-tasks` folder and
__*openshift-applier*__ role.

- #### Jenkins pod is running with a persistent volume
Master configuration is updated to use **jenkins-persistent** template when creating pod for
Jenkins Pipeline Build Strategy.

Following block is added to the `/etc/origin/master/master-config.yaml` on master nodes:
```yaml
jenkinsPipelineConfig:
  autoProvisionEnabled: true
  templateNamespace: openshift
  templateName: jenkins-persistent
  serviceName: jenkins-persistent-svc
```

- #### Jenkins deploys openshift-tasks app
The playbook creates a project for Jenkins CICD named `tasks-build` and the pipeline is defined
in `resources/openshift-tasks/templates/pipeline-bc.yaml` template.

CICD is organized in a way that Jenkins pipeline propagates successful builds to staging projects
`tasks-dev`, `tasks-test` and `tasks-prod`.

- #### Jenkins OpenShift plugin is used to create a CICD workflow
The following fragment in `resources/openshift-tasks/templates/pipeline-bc.yaml` template allows automated
pipeline creation by Jenkins OpenShift plugin in the `tasks-build` namespace:

```yaml
# This is a fragment of resources/openshift-tasks/templates/pipeline-bc.yaml

...

- apiVersion: v1
  kind: BuildConfig
  metadata:
    annotations:
      pipeline.alpha.openshift.io/uses: '[{"name": "${APPLICATION_NAME}", "namespace": "", "kind": "DeploymentConfig"}]'
    labels:
      name: ${APPLICATION_NAME}-pipeline
    name: ${APPLICATION_NAME}-pipeline
    namespace: ${NAMESPACE}
  spec:
    source:
      type: Git
      git:
        uri: ${SOURCE_URL}
        ref: ${SOURCE_REF}
    strategy:
      jenkinsPipelineStrategy:
        jenkinsfile: |-
          openshift.withCluster() {
              env.NAMESPACE = openshift.project()
              env.POM_FILE = env.BUILD_CONTEXT_DIR ? "${env.BUILD_CONTEXT_DIR}/pom.xml" : "pom.xml"
              env.APP_NAME = "${JOB_NAME}".replaceAll(/-build.*/, '')
              echo "Starting Pipeline for ${APP_NAME}..."
              env.BUILD = "${env.NAMESPACE}"
              env.DEV = "${APP_NAME}-dev"
              env.STAGE = "${APP_NAME}-stage"
              env.PROD = "${APP_NAME}-prod"
          }
          ...

```
- #### HPA is configured and working on production deployment of openshift-tasks

## Multitenancy
Two playbooks create Multitenant setup.

1. The `project_default_template.yaml` updates cluster-wide settings to:
- add users *amy* *betty* and *brian* to HTPasswd identity provider on all master nodes
- set ProjectRequestTemplate to 'default/project-requests'
- creates `project-requests` template in the `default` namespace

The `project-requests` template provides following extra settings for new projects:
- project annotation to deny all traffic
- network policy to allow connections between pods ins


2. The `multitenant.yaml` playbook uses __*openshift-applier*__ role to create multitenancy setup from
templates in `resources/multitenant` directory.

- #### Multiple clients/customers created
The `projects` __*openshift-applier*__  object creates 3 projects for customers by applying `resources/multitenant/templates/projects.yaml` template.
  - alpha-corp - for Alpha Corp customer company
  - beta-corp - for Beta Corp customer company
  - common - for other customers

The fragment below has the details of Namespace objects:
```yaml
# fragment from resources/multitenant/templates/projects.yaml file
...
# Alpha Corp project
- kind: Namespace
  apiVersion: v1
  labels:
    client: alpha
  metadata:
    annotations:
      openshift.io/node-selector: client=alpha
    name: alpha-corp
    creationTimestamp: null
  displayName: Alpha Corp
# Beta Corp Project
- kind: Namespace
  apiVersion: v1
  labels:
    client: beta
  metadata:
    annotations:
      openshift.io/node-selector: client=beta
    name: beta-corp
    creationTimestamp: null
  displayName: Beta Corp
# Common project
- kind: Namespace
  apiVersion: v1
  labels:
    client: common
  metadata:
    annotations:
      openshift.io/node-selector: client=common
    name: common
    creationTimestamp: null
  displayName: Unspecified Customers
...
```

Users and groups are created in the same template:
```yaml
# fragment from resources/multitenant/templates/projects.yaml file
...
- kind: Group
  apiVersion: v1
  metadata:
    labels:
      client: alpha
    name: alpha
    namespace: alpha-corp
  users:
  - amy
  - andrew
- apiVersion: v1
  kind: Group
  metadata:
    labels:
      client: beta
    name: beta
    namespace: beta-corp
  users:
  - brian
  - betty
- apiVersion: v1
  kind: Group
  metadata:
    labels:
      client: common
    name: common
    namespace: common
- apiVersion: authorization.openshift.io/v1
  groupNames:
  - alpha
...
```

- #### Dedicated node for each Client
The `resources/multitenant/templates/node_labels.yaml` template defines labels on compute nodes so that those can
be dedicated to specific client.

- node1.$GUID.internal labeled with `client: alpha`
- node2.$GUID.internal labeled with `client: beta`
- node3.$GUID.internal labeled with `client: common`

Template details are below:
```yaml
# resources/multitenant/templates/node_labels.yaml file

apiVersion: v1
kind: Template
labels:
  template: label_customer_nodes
metadata:
  name: label nodes dedicated to customers
objects:
- apiVersion: v1
  kind: Node
  metadata:
    labels:
      client: alpha
    name: "node1.${GUID}.internal"
- apiVersion: v1
  kind: Node
  metadata:
    labels:
      client: beta
    name: "node2.${GUID}.internal"
- apiVersion: v1
  kind: Node
  metadata:
    labels:
      client: common
    name: "node3.${GUID}.internal"
parameters:
- description: Environmnet ID for OpenShift Homework
  name: GUID
  required: true
```
NOTE: The `${GUID}` variable is copied from main playbook's `{{ GUID }}` group variable.

- #### The new project template is modified so that it includes a LimitRange
The `project_default_template.yaml` playbook creates cluster-wide configuration to use new project request template

- #### A new user template is used to create a user object with the specific label value

- #### Alpha and Beta Corp users are confined to projects, and all new pods are deployed to customer dedicated nodes
To allow the users effectively use their projects role bindings are defined.
```yaml
# fragment from resources/multitenant/templates/projects.yaml file
...
  kind: RoleBinding
  metadata:
    name: edit
    namespace: alpha-corp
    selfLink: /apis/authorization.openshift.io/v1/namespaces/alpha-corp/rolebindings/edit
  roleRef:
    name: edit
  subjects:
  - kind: Group
    name: alpha
  userNames: null
- apiVersion: authorization.openshift.io/v1
  groupNames:
  - beta
  kind: RoleBinding
  metadata:
    name: edit
    namespace: beta-corp
    selfLink: /apis/authorization.openshift.io/v1/namespaces/alpha-corp/rolebindings/edit
  roleRef:
    name: edit
  subjects:
  - kind: Group
    name: beta
  userNames: null
- apiVersion: authorization.openshift.io/v1
  groupNames:
  - common
  kind: RoleBinding
  metadata:
    name: edit
    namespace: common
    selfLink: /apis/authorization.openshift.io/v1/namespaces/alpha-corp/rolebindings/edit
  roleRef:
    name: edit
  subjects:
  - kind: Group
    name: common
  userNames: null
```
Now, to ensure pods are created on appropriate node each project has been added `openshift.io/node-selector` annotation
with appropriate label. See `annotations:` property of namespaces in [the previous subsection](#multiple-clientscustomers-created)

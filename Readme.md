[WIP] Homework Assignment
===================
This is a documentation for homework assignment for ocp_advanced_deployment by Aleksandrs Sins

To deploy the cluster run ./install.sh script providing mandatory parameters:

```
./install.sh -g <GUID>
```

The script deploys OpenShift cluster in Red Hat's lab environment assuming that the following nodes have been provisioned by infrastructure:

**loadbalancer node**
- loadbalancer1.$GUID.internal

**masters**
- master1.$GUID.internal
- master2.$GUID.internal
- master3.$GUID.internal


**infra nodes**
- infranode1.$GUID.internal
- infranode2.$GUID.internal


**regular nodes**
- node1.$GUID.internal
- node2.$GUID.internal
- node3.$GUID.internal
- node4.$GUID.internal


**storage node**
- support1.$GUID.internal


## Basic requirements

## HA requirements

## Environment configuration

## CICD Workflow

## Multitenancy
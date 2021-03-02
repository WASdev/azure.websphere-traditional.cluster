# What is this stuff?

- This page specifies content required to create a new plan ("Add additional nodes to the existing cluster") to an Azure application offer ("IBM WebSphere Server ND Traditional V9.0.5 Cluster"). To view details about how to create Azure application offer, pls check out [this page](https://github.com/majguo/arm-rhel-was-nd-cluster/blob/master/arm-rhel-was-nd-cluster/src/main/resources/README.md)

## Plan overview

### New plan

- Plan ID
  - wasndt9-n-cluster-add-node
- Plan name
  - Add additional nodes to the existing cluster

### Plan setup

#### Plan type
- Type of plan
  - Solution template

#### Cloud availability
  - Public azure

### Plan listing

- Name
  - Add additional nodes to the existing cluster
- Summary
  - Provisions additional nodes and add them to the existing WebSphere Application Server Cluster
- Description
  - Provisions additional nodes on RedHat Enterprise Linux 7.4 VMs and add them to the existing IBM WebSphere Application Server ND Traditional V9.0.5 Cluster 

### Availability

#### Plan audience
- This is a private plan.
  - No

#### Hide plan
- No

### Technical configuration

- Version
  - <version_number>
- Package file (.zip)
  - Run `mvn -Dtest.args="-Test All" -Ptemplate-validation-tests clean install`
  - Find `add-nodes-<version_number>-arm-assembly.zip` in the `target` directory

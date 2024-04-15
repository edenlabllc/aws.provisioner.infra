# aws.provisioner.infra
This repository provides terraform templates and manifests. 
Mainly it is designed to be managed by administrators, DevOps engineers, SREs.

## Contents
* [Requirements](#requirements)
* [Git flow strategy](#git-flow-strategy)
* [Additional information](#additional-information)
* [Emergency cluster destroy](#emergency-cluster-destroy)
* [Development](#development)

## Requirements:
terraform = version is specified in the project file of each tenant of the repository in section `tools`.

## Git flow strategy
This repository uses the [GitFlow](https://www.atlassian.com/git/tutorials/comparing-workflows/gitflow-workflow) approach.

#### Stable branches: develop, master
Each merge in the master branch adds a new SemVer2 tag and a GitHub release is created.

## Additional information
This set of terraform manifests can only be launched from the tenant repository via the RMK, 
because the entire input set of variables is formed by the RMK at the moment 
the commands are launched: `rmk cluster provision` or `rmk cluster destroy`.
RMK also keeps track of which version of the release of terraform manifests the tenant repository will use.
The version of terraform manifests artifact is described in the version file of each 
tenant repository in the section `inventory.clusters`.

## Emergency cluster destroy
Script for emergency destroy of a tenant's cluster in the case when native terraform tools fail to do this.

### Requirements:
* AWS CLI >= 2.9
* curl
* aws-nuke >= v2.25.0
* yq >= v4.35.2

```shell
cd emergency-cluster-destroy
./emergency-cluster-removal.sh <AWS profile name> <Cloudflare token>
```

> Note: Follow the script's interactive instructions for correct execution.

## Development
For development, you need to use one of the tenant repositories and change the code 
in the directory `.PROJECT/clusters/aws.provisioner.infra-<version>/terraform`. 
After developing and refactoring code, copy change files to this repository in feature branch and create Pull Request.

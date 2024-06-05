# aws.provisioner.infra

[![Release](https://img.shields.io/github/v/release/edenlabllc/aws.provisioner.infra.svg?style=for-the-badge)](https://github.com/edenlabllc/aws.provisioner.infra/releases/latest)
[![Software License](https://img.shields.io/github/license/edenlabllc/aws.provisioner.infra.svg?style=for-the-badge)](LICENSE)
[![Powered By: Edenlab](https://img.shields.io/badge/powered%20by-edenlab-8A2BE2.svg?style=for-the-badge)](https://edenlab.io)

This repository provides [Terraform](https://www.terraform.io/) templates and manifests. 
Mainly it is designed to be managed by administrators, DevOps engineers, SREs.

## Contents

* [Requirements](#requirements)
* [Git workflow](#git-workflow)
* [Additional information](#additional-information)
* [Emergency cluster destroy](#emergency-cluster-destroy)
* [Development](#development)

## Requirements

`terraform` = version is specified in the [project.yaml](https://github.com/edenlabllc/rmk/blob/develop/docs/configuration/project-management/preparation-of-project-repository.md#projectyaml) file 
of each project of the repository in the `tools` section.

## Git workflow

This repository uses the classic [GitFlow](https://www.atlassian.com/git/tutorials/comparing-workflows/gitflow-workflow) workflow, 
embracing all its advantages and disadvantages.

**Stable branches:** develop, master

Each merge in the master branch adds a new [SemVer2](https://semver.org/) tag and a GitHub release is created.

## Additional information

This set of Terraform manifests can only be launched from the project repository via [RMK](https://github.com/edenlabllc/rmk), 
because the entire input set of variables is formed by RMK at the moment 
the commands are launched: `rmk cluster provision` or `rmk cluster destroy`.
RMK also keeps track of which version of the release of Terraform manifests the project repository will use.
The version of Terraform manifests artifact is described in the [project.yaml](https://github.com/edenlabllc/rmk/blob/develop/docs/configuration/project-management/preparation-of-project-repository.md#projectyaml) file of each 
project repository in the section:

```yaml
inventory:
  clusters:
    aws.provisioner.infra:
      version: <SemVer2>
      url: git::https://github.com/edenlabllc/{{.Name}}.git?ref={{.Version}}
```

## Emergency cluster destroy

Script for emergency destroy of a project's cluster in the case when native Terraform tools fail to do this.

**Requirements:**

* [AWS CLI](https://aws.amazon.com/cli/) >= 2.9
* [cURL](https://curl.se/)
* [aws-nuke](https://github.com/rebuy-de/aws-nuke) >= v2.25.0
* [yq](https://mikefarah.gitbook.io/yq) >= v4.35.2

```shell
cd emergency-cluster-destroy
./emergency-cluster-destroy.sh <aws_profile_name> <cloudflare_token>
```

> Follow the script's interactive instructions for correct execution.

## Development

For development, navigate to the local `.PROJECT/clusters/aws.provisioner.infra-<version>/terraform` directory of a project repository, 
then perform the changes directly in the files and test them. 
Finally, copy the changed files to a new feature branch of this repository and create a pull request (PR).

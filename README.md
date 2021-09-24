# Udacity Azure Dev-Ops Projet 1

This is a project related to Udacity Azure DevOps nanodegree.
It aims at deploying a policy, an image from a Packer template that will be used by Terraform.

## Dependencies

An Azure account
Packer
Terraform

## Deploy

### Export the variable

Add to your .bashrc (or .zshrc) file:

```
export AZ_CLIENT_ID=00000000-0000-0000-0000-000000000000
export AZ_CLIENT_SECRET=000000000000000000000
export AZ_TENANT_ID=00000000-0000-0000-0000-000000000000
export AZ_SUSCRIPTION_ID=00000000-0000-0000-0000-000000000000
```

(Obviously, change the value with yours.)

### Create a resource group

Either from the portal or the CLI, create a new resource group or the projet, in my case it is udacity-assignment1-rg.

### Deploy the policy

Deploy the policy (I did it on the Portal) and assign it to the resource group.

### Deploy the Packer image

```
$ packer build packer/server.json
```

### Deploy with Terraform

```
$ terraform init
$ terraform plan -out solution.plan
```

## After

Destroy the infrastructure with:

```
$ terraform deploy
```

## Modify

The file `terraform/vars.tf` contains all the variables used inside the `terraform/main.tf`. If you want to personnalize the code, it is likely those values you want to modify first.
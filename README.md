# Deploying Sourcegraph on DigitalOcean

This Terraform plan creates an SSH key and Droplet and deploys the latest stable version of Sourcegraph with TLS using a self-signed certificate.

## Prerequisites

- Make
- [Terraform](https://learn.hashicorp.com/terraform/getting-started/install.html)
- [mkcert](https://github.com/FiloSottile/mkcert) (optional but required for self-signed cert validation)

> NOTE: A basic level of knowledge and experience using [Terraform](https://www.terraform.io/intro/index.html) is required.

## Terraform DigitalOcean authentication

Authentication requires a a [DigitalOcean API token](https://www.digitalocean.com/docs/api/create-personal-access-token/) set to the `DIGITALOCEAN_TOKEN` environment variable.

## Terraform plan configuration

The existence of a `terraform.tfvars` file is required. To create it, copy the contents of `terraform.tfvars.sample` to a new `terraform.tfvars` file and review to see which variables (if any) you'd like to set.

> The only required variable is `ssh_key_file`.

## Commands

The `Makefile` has commands to cover the most common use-cases. The easiest way to create your Droplet is to run:

```bash
make deploy
```

This will create the Droplet and poll the server to let you know when Sourcegraph is ready.

Other commands include:

- `make init`: Download the required Terraform provider packages.
- `make plan`: Is there anything required to add, change or remove?
- `make apply`: Create the Droplet and SSH key.
- `make sourcegraph`: Waits for Sourcegraph to accept connections.
- `make output`: Display the same output as when `make apply` completes.
- `make destroy`: Removes the droplet and SSH key.

> WARNING: `make destroy` will destroy the Droplet so back-up the `/etc/sourcegraph` and `/var/opt/sourcegraph` directories first.

## Upgrading Sourcegraph

1. SSH into the Droplet
1. Run `./sourcegraph-upgrade`

The newer Docker image will be pulled and Sourcegraph will be restarted.

## Troubleshooting

```bash
./bin/wait-for-it.sh: line 58: timeout: command not found
```

The `bin/wait-for-it.sh` script uses the `timeout` binary which is not included in macOS. Install using homebrew:

```bash
  brew install coreutils
```

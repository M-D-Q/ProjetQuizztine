#! /bin/bash
cd ./terraform_scripts
terraform init -upgrade
terraform plan -out main.tfplan
terraform apply main.tfplan
terraform output -raw tls_private_key > id_rsa
terraform output public_ip_addresses

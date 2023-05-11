all:
  children:
    database-master:
      hosts:
        postgresql-master:
          ansible_host: "${master_ip}"
          ansible_user: azureuser
          ansible_ssh_private_key_file: ../id_rsa

    database-slave:
      hosts:
        postgresql-slave:
          ansible_host: "${slave_ip}"
          ansible_user: azureuser
          ansible_ssh_private_key_file: ../id_rsa

    lb-database:
      hosts:
        lb-database:
          ansible_host: "${lb_ip}"
          ansible_user: azureuser
          ansible_ssh_private_key_file: ../id_rsa

    flask:
      hosts:
        flask:
          ansible_host: "${flask_ip}"
          ansible_user: azureuser
          ansible_ssh_private_key_file: ../id_rsa

    monitoring:
      hosts:
        monitoring:
          ansible_host: "${monitoring_ip}"
          ansible_user: azureuser
          ansible_ssh_private_key_file: ../id_rsa

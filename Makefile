.PHONY: all init plan apply destroy ansible-lint terraform-lint ansible-deploy help

# Directories
TERRAFORM_DIR := terraform
ANSIBLE_DIR := ansible

# Default target
all: init plan apply create-inventory ansible-deploy
	@echo "Complete deployment finished successfully!"

help:
	@echo "Available targets:"
	@echo "  init           - Initialize Terraform"
	@echo "  plan           - Create Terraform plan"
	@echo "  apply          - Apply Terraform changes"
	@echo "  destroy        - Destroy Terraform infrastructure"
	@echo "  create-inventory - Generate Ansible inventory from Terraform outputs"
	@echo "  ansible-lint   - Run Ansible linter"
	@echo "  ansible-deploy - Run Ansible playbook"
	@echo "  terraform-lint - Run Terraform formatting and validation"
	@echo
	@echo "Example usage:"
	@echo "  make all       - Runs init, plan, apply, inventory, and ansible-deploy"

# Terraform targets
init:
	cd $(TERRAFORM_DIR) && terraform init

plan:
	cd $(TERRAFORM_DIR) && terraform plan

apply:
	cd $(TERRAFORM_DIR) && terraform apply -auto-approve

destroy:
	cd $(TERRAFORM_DIR) && terraform destroy -auto-approve

# Generate Ansible inventory
create-inventory:
	cd $(TERRAFORM_DIR) && pwsh ./inventory.ps1

# Ansible targets
ansible-lint:
	ansible-lint $(ANSIBLE_DIR)/

ansible-deploy:
	cd $(ANSIBLE_DIR) && ansible-playbook -i hosts.yml --become --become-user=root playbook.yml

# Terraform linting and validation
terraform-lint:
	cd $(TERRAFORM_DIR) && terraform fmt -check && terraform validate

SHELL: /bin/bash

.ONESHELL:

.DEFAULT_GOAL := local-env

test:
	.bin/profile-install.sh standard-cluster-deployment

local-env:
	.bin/kind.sh

local-destroy:
	@echo "Deleting kind mgmt (control-plan) and testing (workload) clusters"
	kind delete clusters mgmt testing
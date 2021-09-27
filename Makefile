SHELL: /bin/bash

.ONESHELL:

.DEFAULT_GOAL := local-env


local-env:
	.bin/kind.sh

local-destroy:
	@echo "Deleting kind mgmt (control-plan) and testing (workload) clusters"
	kind delete clusters mgmt testing
SHELL: /bin/bash

.ONESHELL:

local-env:
	.bin/kind.sh

local-destroy:
	kind delete clusters mgmt testing
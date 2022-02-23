SHELL: /bin/bash
.ONESHELL:


OS := $(shell uname | tr '[:upper:]' '[:lower:]')
CONFDIR="${PWD}/.conf"
BINDIR="${PWD}/.bin"
REPODIR="${PWD}/charts"
INFRASTRUCTURE?="kind"

test:
	@echo "Testing platform"
	bash ${BINDIR}/test-platform.sh ${INFRASTRUCTURE}

sort-layers:
	@echo "Sorting charts by layers"
	bash ${BINDIR}/sort-layers.sh
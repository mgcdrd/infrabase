.DEFAULT_GOAL := help

VENV    ?= .venv
PYTHON  ?= python3
MOLECULE     := $(CURDIR)/$(VENV)/bin/molecule
ANSIBLE_LINT := $(CURDIR)/$(VENV)/bin/ansible-lint

# Molecule loads this collection as mgcdrd.infrabase via a symlink tree.
COLL_ROOT := $(CURDIR)/.molecule/collections
export ANSIBLE_COLLECTIONS_PATH := $(COLL_ROOT)
export MOLECULE_BASE_CONFIG     := $(CURDIR)/.config/molecule/config.yml

.PHONY: help setup link lint test list-scenarios test-%

help:
	@echo "make setup         Create .venv and install molecule + ansible-lint"
	@echo "make link          Refresh the collection symlink tree molecule loads"
	@echo "make lint          Run ansible-lint over the collection"
	@echo "make test          Run every role's molecule scenarios"
	@echo "make test-<role>   Run one role's molecule scenario (e.g. make test-postgresql)"

setup:
	$(PYTHON) -m venv $(VENV)
	$(VENV)/bin/pip install --upgrade pip
	$(VENV)/bin/pip install -r requirements-dev.txt

link:
	mkdir -p $(COLL_ROOT)/ansible_collections/mgcdrd
	ln -sfn $(CURDIR) $(COLL_ROOT)/ansible_collections/mgcdrd/infrabase

lint: link
	$(ANSIBLE_LINT)

test: link
	@set -e; for d in roles/*/molecule/*/; do \
	  role=$$(echo $$d | cut -d/ -f2); scen=$$(basename $$d); \
	  echo ">>> $$role : $$scen"; \
	  ( cd roles/$$role && $(MOLECULE) test -s $$scen ); \
	done

test-%: link
	cd roles/$* && $(MOLECULE) test

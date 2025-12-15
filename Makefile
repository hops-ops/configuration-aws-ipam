SHELL := /bin/bash

PACKAGE ?= configuration-aws-ipam
XRD_DIR := apis/ipams
COMPOSITION := $(XRD_DIR)/composition.yaml
DEFINITION := $(XRD_DIR)/definition.yaml
EXAMPLE_DEFAULT := examples/ipams/example-minimal.yaml
EXAMPLES := $(wildcard examples/ipams/*.yaml)
RENDER_TESTS := $(wildcard tests/test-*)
E2E_TESTS := $(wildcard tests/e2etest-*)

clean:
	rm -rf _output
	rm -rf .up

build:
	up project build

render: render-example

render-example:
	up composition render $(COMPOSITION) $(EXAMPLE_DEFAULT)

render-all:
	@for example in $(EXAMPLES); do \
		echo "Rendering $$example"; \
		up composition render $(COMPOSITION) $$example; \
	done

# Multi-step rendering for example-private-ipv6
render-example-private-ipv6:
	up composition render --xrd=$(DEFINITION) $(COMPOSITION) examples/ipams/example-private-ipv6.yaml

render-example-private-ipv6-step-1:
	up composition render --xrd=$(DEFINITION) $(COMPOSITION) examples/ipams/example-private-ipv6.yaml \
		--observed-resources=examples/observed-resources/example-private-ipv6/steps/1/

render-example-private-ipv6-step-2:
	up composition render --xrd=$(DEFINITION) $(COMPOSITION) examples/ipams/example-private-ipv6.yaml \
		--observed-resources=examples/observed-resources/example-private-ipv6/steps/2/

render-example-private-ipv6-step-3:
	up composition render --xrd=$(DEFINITION) $(COMPOSITION) examples/ipams/example-private-ipv6.yaml \
		--observed-resources=examples/observed-resources/example-private-ipv6/steps/3/

test:
	up test run $(RENDER_TESTS)

validate: validate-composition validate-examples

validate-composition:
	up composition render $(COMPOSITION) $(EXAMPLE_DEFAULT) --include-full-xr --quiet | crossplane beta validate $(XRD_DIR) --error-on-missing-schemas -

validate-examples:
	crossplane beta validate $(XRD_DIR) examples/ipams

# Validation with observed resources
validate-example-private-ipv6:
	up composition render --xrd=$(DEFINITION) $(COMPOSITION) examples/ipams/example-private-ipv6.yaml \
		--include-full-xr --quiet | crossplane beta validate $(XRD_DIR) --error-on-missing-schemas -

validate-example-private-ipv6-step-1:
	up composition render --xrd=$(DEFINITION) $(COMPOSITION) examples/ipams/example-private-ipv6.yaml \
		--observed-resources=examples/observed-resources/example-private-ipv6/steps/1/ \
		--include-full-xr --quiet | crossplane beta validate $(XRD_DIR) --error-on-missing-schemas -

validate-example-private-ipv6-step-2:
	up composition render --xrd=$(DEFINITION) $(COMPOSITION) examples/ipams/example-private-ipv6.yaml \
		--observed-resources=examples/observed-resources/example-private-ipv6/steps/2/ \
		--include-full-xr --quiet | crossplane beta validate $(XRD_DIR) --error-on-missing-schemas -

validate-example-private-ipv6-step-3:
	up composition render --xrd=$(DEFINITION) $(COMPOSITION) examples/ipams/example-private-ipv6.yaml \
		--observed-resources=examples/observed-resources/example-private-ipv6/steps/3/ \
		--include-full-xr --quiet | crossplane beta validate $(XRD_DIR) --error-on-missing-schemas -

publish:
	@if [ -z "$(tag)" ]; then echo "Error: tag is not set. Usage: make publish tag=<version>"; exit 1; fi
	up project build --push --tag $(tag)

generate-definitions:
	up xrd generate $(EXAMPLE_DEFAULT)

generate-function:
	up function generate --language=go-templating render $(COMPOSITION)

e2e:
	up test run $(E2E_TESTS) --e2e


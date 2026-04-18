SHELL  := /bin/bash
BUILD_DIR   := build
LAYER_BUILD := lambda/layer
AGENT_BUILD := agent/build

UNAME_S := $(shell uname -s)
UNAME_M := $(shell uname -m)

.PHONY: build build-layer build-agent test-upload clean

build: build-layer build-agent

build-layer:
	@echo "Building Lambda layer (x86_64, python3.12)..."
	mkdir -p $(LAYER_BUILD)/python $(BUILD_DIR)
	uv export --group lambda --frozen --no-hashes --no-emit-project \
		-o /tmp/lambda-reqs.txt
ifeq ($(UNAME_S)$(UNAME_M),Linuxx86_64)
	@echo "  Native Linux x86_64 install"
	pip install \
		--python-version 312 \
		--only-binary :all: \
		--target $(LAYER_BUILD)/python \
		-r /tmp/lambda-reqs.txt
else
	@echo "  Cross-compiling for Linux x86_64 from $(UNAME_S)/$(UNAME_M)"
	pip install \
		--platform manylinux2014_x86_64 \
		--python-version 312 \
		--only-binary :all: \
		--target $(LAYER_BUILD)/python \
		-r /tmp/lambda-reqs.txt
endif
	cd $(LAYER_BUILD) && zip -r ../../$(BUILD_DIR)/lambda_layer.zip python/
	@echo "Done: $(BUILD_DIR)/lambda_layer.zip"

build-agent:
	@echo "Building AgentCore agent (ARM64, python3.12)..."
	mkdir -p $(AGENT_BUILD) $(BUILD_DIR)
	uv export --group agent --frozen --no-hashes --no-emit-project \
		-o /tmp/agent-reqs.txt
	pip install \
		--platform manylinux2014_aarch64 \
		--python-version 312 \
		--only-binary :all: \
		--target $(AGENT_BUILD) \
		-r /tmp/agent-reqs.txt
	cp agent/agent.py $(AGENT_BUILD)/
	cp lambda/classifications.json $(AGENT_BUILD)/
	cd $(AGENT_BUILD) && zip -r ../../$(BUILD_DIR)/agent.zip .
	@echo "Done: $(BUILD_DIR)/agent.zip"

test-upload:
	@[ "$(FILE)" ] || { echo "Usage: make test-upload FILE=path/to/receipt.jpg|.heic"; exit 1; }
	$(eval ACCOUNT_ID := $(shell aws sts get-caller-identity --query Account --output text))
	$(eval BUCKET := mojodojo-receipt-classifier-$(ACCOUNT_ID)-input)
	$(eval UPLOAD_FILE := $(shell \
		ext=$$(echo "$(FILE)" | sed 's/.*\.//' | tr '[:upper:]' '[:lower:]'); \
		if [ "$$ext" = "heic" ]; then \
			out=/tmp/$$(basename "$(FILE)" .$$ext).jpg; \
			sips -s format jpeg "$(FILE)" --out "$$out" >/dev/null; \
			echo "$$out"; \
		else \
			echo "$(FILE)"; \
		fi))
	$(eval KEY := uploads/$(notdir $(UPLOAD_FILE)))
	aws s3 cp "$(UPLOAD_FILE)" s3://$(BUCKET)/$(KEY)
	@echo "Uploaded to s3://$(BUCKET)/$(KEY)"
	@echo ""
	@echo "To view logs:"
	@echo "  aws logs tail /aws/lambda/receipt-classifier-processor --since 5m --format short"
	@echo ""
	@echo "To view latest classification result:"
	@echo "  make show-results"

show-results:
	$(eval ACCOUNT_ID := $(shell aws sts get-caller-identity --query Account --output text))
	$(eval LATEST := $(shell aws s3 ls s3://mojodojo-receipt-classifier-$(ACCOUNT_ID)-output/results/ | sort | tail -1 | awk '{print $$4}'))
	@[ "$(LATEST)" ] || { echo "No results found in output bucket yet."; exit 1; }
	aws s3 cp s3://mojodojo-receipt-classifier-$(ACCOUNT_ID)-output/results/$(LATEST) - | python3 -m json.tool

clean:
	rm -rf $(LAYER_BUILD) $(AGENT_BUILD) $(BUILD_DIR)

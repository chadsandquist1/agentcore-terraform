SHELL := /bin/bash
BUILD_DIR  := build
LAYER_BUILD := lambda/layer
AGENT_BUILD := agent/build

.PHONY: build build-layer build-agent test-upload clean

build: build-layer build-agent

build-layer:
	@echo "Building Lambda layer (x86_64, python3.12)..."
	mkdir -p $(LAYER_BUILD)/python $(BUILD_DIR)
	uv export --group lambda --frozen --no-hashes --no-emit-project \
		-o /tmp/lambda-reqs.txt
	uv pip install \
		--python 3.12 \
		--platform manylinux2014_x86_64 \
		--only-binary :all: \
		--target $(LAYER_BUILD)/python \
		-r /tmp/lambda-reqs.txt
	cd $(LAYER_BUILD) && zip -r ../../$(BUILD_DIR)/lambda_layer.zip python/
	@echo "Done: $(BUILD_DIR)/lambda_layer.zip"

build-agent:
	@echo "Building AgentCore agent (ARM64, python3.12)..."
	mkdir -p $(AGENT_BUILD) $(BUILD_DIR)
	uv export --group agent --frozen --no-hashes --no-emit-project \
		-o /tmp/agent-reqs.txt
	uv pip install \
		--python 3.12 \
		--platform aarch64-manylinux2014 \
		--only-binary :all: \
		--target $(AGENT_BUILD) \
		-r /tmp/agent-reqs.txt
	cp agent/agent.py $(AGENT_BUILD)/
	cp lambda/classifications.json $(AGENT_BUILD)/
	cd $(AGENT_BUILD) && zip -r ../../$(BUILD_DIR)/agent.zip .
	@echo "Done: $(BUILD_DIR)/agent.zip"

test-upload:
	@[ "$(FILE)" ] || { echo "Usage: make test-upload FILE=my_receipt.jpg"; exit 1; }
	$(eval ACCOUNT_ID := $(shell aws sts get-caller-identity --query Account --output text))
	$(eval BUCKET := mojodojo-receipt-classifier-$(ACCOUNT_ID)-input)
	$(eval KEY := uploads/$(notdir $(FILE)))
	aws s3 cp $(FILE) s3://$(BUCKET)/$(KEY)
	@echo "Uploaded to s3://$(BUCKET)/$(KEY)"
	@echo "Tailing logs (Ctrl+C to stop):"
	aws logs tail /aws/lambda/receipt-classifier-processor --follow --format short

clean:
	rm -rf $(LAYER_BUILD) $(AGENT_BUILD) $(BUILD_DIR)

SHELL  := /bin/bash
BUILD_DIR   := build
LAYER_BUILD := lambda/layer
AGENT_BUILD := agent/build

UNAME_S := $(shell uname -s)
UNAME_M := $(shell uname -m)

.PHONY: build build-layer build-agent build-api build-frontend deploy-frontend test-upload show-results clean

build: build-layer build-agent build-api

build-layer:
	@echo "Building Lambda layer (x86_64, python3.12)..."
	mkdir -p $(LAYER_BUILD)/python $(BUILD_DIR)
	uv export --group lambda --frozen --no-hashes --no-emit-project \
		-o /tmp/lambda-reqs.txt
	sed 's/ ;.*//' /tmp/lambda-reqs.txt | grep -v '^#' | grep -v '^$$' > /tmp/lambda-reqs-clean.txt
ifeq ($(UNAME_S)$(UNAME_M),Linuxx86_64)
	@echo "  Native Linux x86_64 install"
	pip install \
		--python-version 312 \
		--only-binary :all: \
		--target $(LAYER_BUILD)/python \
		-r /tmp/lambda-reqs-clean.txt
else
	@echo "  Cross-compiling for Linux x86_64 from $(UNAME_S)/$(UNAME_M)"
	pip install \
		--platform manylinux2014_x86_64 \
		--python-version 312 \
		--only-binary :all: \
		--target $(LAYER_BUILD)/python \
		-r /tmp/lambda-reqs-clean.txt
endif
	cd $(LAYER_BUILD) && zip -r ../../$(BUILD_DIR)/lambda_layer.zip python/
	@echo "Done: $(BUILD_DIR)/lambda_layer.zip"

build-agent:
	@echo "Building AgentCore agent (ARM64, python3.12)..."
	mkdir -p $(AGENT_BUILD) $(BUILD_DIR)
	uv export --group agent --frozen --no-hashes --no-emit-project \
		-o /tmp/agent-reqs.txt
	sed 's/ ;.*//' /tmp/agent-reqs.txt | grep -v '^#' | grep -v '^$$' > /tmp/agent-reqs-clean.txt
	pip install \
		--platform manylinux2014_aarch64 \
		--python-version 312 \
		--only-binary :all: \
		--target $(AGENT_BUILD) \
		-r /tmp/agent-reqs-clean.txt
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

build-api:
	@echo "Packaging API Lambda..."
	mkdir -p $(BUILD_DIR)
	zip -j $(BUILD_DIR)/api_handler.zip lambda/api_handler.py
	@echo "Done: $(BUILD_DIR)/api_handler.zip"

build-frontend:
	@echo "Building Next.js frontend..."
	$(eval API_URL := $(shell cd terraform && terraform output -raw api_url 2>/dev/null))
	$(eval CLIENT_ID := $(shell cd terraform && terraform output -raw cognito_client_id 2>/dev/null))
	@[ "$(API_URL)" ] || { echo "Run 'terraform apply' first to get outputs."; exit 1; }
	@printf "NEXT_PUBLIC_API_URL=%s\nNEXT_PUBLIC_COGNITO_USER_POOL_ID=us-east-1_jCtPXwqXV\nNEXT_PUBLIC_COGNITO_CLIENT_ID=%s\n" \
		"$(API_URL)" "$(CLIENT_ID)" > frontend/.env.production
	cd frontend && npm ci && npm run build
	@echo "Done: frontend/out/"

deploy-frontend: build-frontend
	@echo "Deploying frontend to S3 + CloudFront..."
	$(eval BUCKET := $(shell cd terraform && terraform output -raw frontend_bucket 2>/dev/null))
	$(eval CF_ID := $(shell cd terraform && terraform output -raw cloudfront_distribution_id 2>/dev/null))
	$(eval CF_URL := $(shell cd terraform && terraform output -raw cloudfront_url 2>/dev/null))
	aws s3 sync frontend/out/ s3://$(BUCKET)/ --delete
	aws cloudfront create-invalidation --distribution-id $(CF_ID) --paths "/*" --output text
	@echo ""
	@echo "Frontend live at: $(CF_URL)"

clean:
	rm -rf $(LAYER_BUILD) $(AGENT_BUILD) $(BUILD_DIR) frontend/out frontend/.env.production

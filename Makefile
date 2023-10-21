.DEFAULT_GOAL := help

help:
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

OS := $(shell uname)

GENERATE_PROTOS_FLAG :=

.PHONY: build
build: ## Build based on the OS.
ifeq ($(OS),Linux)
	./build.sh $(GENERATE_PROTOS_FLAG)
else ifeq ($(OS),Darwin)
	./build.sh $(GENERATE_PROTOS_FLAG)
else
	.\build.ps1 $(GENERATE_PROTOS_FLAG)
endif

.PHONY: generate-protos
generate-protos: ## Regenerate protobuf and gRPC files while building.
ifeq ($(OS),Linux)
	$(eval GENERATE_PROTOS_FLAG := --generate-protos)
else
	$(eval GENERATE_PROTOS_FLAG := -generateProtos)
endif
	build


DOCKER_COMPOSE_CMD := $(shell command -v docker-compose 2> /dev/null)
ifeq ($(DOCKER_COMPOSE_CMD),)
	DOCKER_COMPOSE_CMD := docker compose
endif

.PHONY: singleNode
singleNode: ## Run tests against a single node.
	@EVENTSTORE_INSECURE=true go test -count=1 -v ./esdb -run 'TestStreams|TestPersistentSubscriptions|Expectations'

.PHONY: secureNode
secureNode: ## Run tests against a secure node.
	@$(DOCKER_COMPOSE_CMD) down -v
	@$(DOCKER_COMPOSE_CMD) pull
	@$(DOCKER_COMPOSE_CMD) up -d
	@EVENTSTORE_INSECURE=false go test -v ./esdb -run 'TestStreams|TestPersistentSubscriptions'
	@$(DOCKER_COMPOSE_CMD) down

.PHONY: clusterNode
clusterNode: ## Run tests against a cluster node.
	@$(DOCKER_COMPOSE_CMD) -f cluster-docker-compose.yml down --remove-orphans -v
	@$(DOCKER_COMPOSE_CMD) -f cluster-docker-compose.yml pull
	@$(DOCKER_COMPOSE_CMD) -f cluster-docker-compose.yml up -d
	@echo "Waiting for services to be fully ready..."
	@sleep 5
	@EVENTSTORE_INSECURE=false CLUSTER=true go test -count=1 -v ./esdb -run 'TestStreams|TestPersistentSubscriptions'
	@$(DOCKER_COMPOSE_CMD) -f cluster-docker-compose.yml down --remove-orphans

.PHONY: test 
test: singleNode secureNode clusterNode ## Run all tests.
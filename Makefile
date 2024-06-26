# self-documenting Makefile

.PHONY: help

help: ## Display this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n\nTargets:\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

repoinit: ## initialize empty repo skeleton for smartos image
	./mibe_repoinit.sh $(filter-out $@,$(MAKECMDGOALS))

vm: ## create mibe VM
	./mibe_vm.sh $(filter-out $@,$(MAKECMDGOALS))

%:
	@:

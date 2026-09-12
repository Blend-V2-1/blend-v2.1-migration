V2_DIR := blend-contracts-v2
BACKFILL_DIR := blnt-backfill-contract
COMET_DIR := comet-contracts-v1.1

.PHONY: build test localnet-plan localnet-validate localnet-start localnet-deploy \
	localnet-run localnet-status localnet-stop testnet-plan testnet-validate \
	testnet-start testnet-deploy testnet-run testnet-status

build:
	bash scripts/build-v2.sh
	$(MAKE) -C $(BACKFILL_DIR) build
	$(MAKE) -C $(COMET_DIR) build

test: build
	cd $(V2_DIR) && cargo test --all --tests --locked
	$(MAKE) -C $(BACKFILL_DIR) test
	$(MAKE) -C $(COMET_DIR) test

localnet-plan:
	bash scripts/deploy-v2.1.sh plan

localnet-validate:
	bash scripts/deploy-v2.1.sh validate

localnet-start:
	bash scripts/deploy-v2.1.sh start

localnet-deploy:
	bash scripts/deploy-v2.1.sh deploy

localnet-run:
	bash scripts/deploy-v2.1.sh run

localnet-status:
	bash scripts/deploy-v2.1.sh status

localnet-stop:
	bash scripts/deploy-v2.1.sh stop

testnet-plan:
	BLEND_V21_NETWORK=testnet bash scripts/deploy-v2.1.sh plan

testnet-validate:
	BLEND_V21_NETWORK=testnet bash scripts/deploy-v2.1.sh validate

testnet-start:
	BLEND_V21_NETWORK=testnet bash scripts/deploy-v2.1.sh start

testnet-deploy:
	BLEND_V21_NETWORK=testnet bash scripts/deploy-v2.1.sh deploy

testnet-run:
	BLEND_V21_NETWORK=testnet bash scripts/deploy-v2.1.sh run

testnet-status:
	BLEND_V21_NETWORK=testnet bash scripts/deploy-v2.1.sh status

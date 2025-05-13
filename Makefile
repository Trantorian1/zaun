# TODO: this can be rewritten as build.rs in the sandbox crate,
# but it might introduce unnecessary friction and longer build times.
# Moreover, any project using sandbox as dependency won't build unless
# there's Foundry installed on the machine.

.PHONY: piltover cairo-lang local-contracts starkgate-contracts-latest starkgate-contracts-old l2-artifacts

CAIRO_LANG_RELEASE_VERSION="8e11b8cc65ae1d0959328b1b4a40b92df8b58595" # Version : 0.13.2, Not using version because it is causing issues in `cargo build`.
STARKGATE_CONTRACTS_RELEASE_VERSION="45941888479663ac93e898cd7f8504fa9066c54c" # Version : 2.0.1
STARKGATE_LEGACY_CONTRACTS_COMMIT_HASH="82e651f5f642508577b6310f47d0d457f5f9a9bb" # branch  update 0.9.0

piltover:
	(cd lib/piltover && scarb build && cp target/dev/* ../../crates/l3/appchain-core-contract-client/artifacts)

cairo-lang:
	# Building
	cp build-artifacts/cairo-lang/foundry.toml lib/cairo-lang/foundry.toml
	cd lib/cairo-lang && \
 	git checkout $(CAIRO_LANG_RELEASE_VERSION) && \
 	forge build
	# Copying Contracts :
	mkdir -p artifacts/cairo-lang
	cp lib/cairo-lang/out/Starknet.sol/Starknet.json artifacts/cairo-lang/Starknet.json

local-contracts:
	# Building
	forge build
	# Copying Contracts :
	cp out/StarknetDevCoreContract.sol/Starknet.json artifacts/StarknetDevCoreContract.json
	cp out/UnsafeProxy.sol/UnsafeProxy.json artifacts/UnsafeProxy.json

starkgate-contracts-latest:
	# Configure solidity version
	solc-select install 0.8.24 && solc-select use 0.8.24
	# Building
	cd lib/starkgate-contracts && \
	git checkout $(STARKGATE_CONTRACTS_RELEASE_VERSION) && \
	./scripts/setup.sh && \
	FILES=$$(cat src/solidity/files_to_compile.txt) && \
	solc $$FILES --allow-paths .=., --optimize --optimize-runs 200 --overwrite --combined-json abi,bin -o artifacts && \
	./scripts/extract_artifacts.py
	# building ERC20 (test)
	cp build-artifacts/starkgate-contracts/foundry.toml lib/starkgate-contracts/starkware/solidity/foundry.toml && \
	cd lib/starkgate-contracts/starkware/solidity && \
	echo "pragma solidity ^0.8.0; import \"./ERC20.sol\"; contract ERC20_1 is ERC20 { constructor() { _mint(msg.sender, 100000000000); } }" > ./tokens/ERC20/ERC20_1.sol && \
	forge build
	# Copying Contracts :
	mkdir -p artifacts/starkgate-contracts
	cp lib/starkgate-contracts/artifacts/StarkgateManager.json artifacts/starkgate-contracts/StarkgateManager.json
	cp lib/starkgate-contracts/artifacts/StarkgateRegistry.json artifacts/starkgate-contracts/StarkgateRegistry.json
	cp lib/starkgate-contracts/artifacts/Proxy.json artifacts/starkgate-contracts/Proxy_5_0_0.json
	cp lib/starkgate-contracts/artifacts/StarknetTokenBridge.json artifacts/starkgate-contracts/StarknetTokenBridge.json
	cp lib/starkgate-contracts/starkware/solidity/out/ERC20_1.sol/ERC20_1.json artifacts/starkgate-contracts/ERC20.json

starkgate-contracts-old:
	# Configure solidity version
	solc-select install 0.6.12 && solc-select use 0.6.12
	# Building
	cp build-artifacts/starkgate-contracts-0.9/foundry.toml lib/starkgate-contracts-0.9/src/starkware/solidity/foundry.toml
	cp build-artifacts/starkgate-contracts-0.9/foundry2.toml lib/starkgate-contracts-0.9/src/starkware/foundry.toml
	cd lib/starkgate-contracts-0.9/src/starkware/solidity && \
	forge build
	cd lib/starkgate-contracts-0.9/src/starkware && \
	forge build
	# Copying Contracts :
	mkdir -p artifacts/starkgate-contracts-0.9
	cp lib/starkgate-contracts-0.9/src/starkware/solidity/out/Proxy.sol/Proxy.json artifacts/starkgate-contracts-0.9/Proxy_3_0_2.json

starkgate-contracts-82e651f:
	# Configure solidity version
	solc-select install 0.6.12 && solc-select use 0.6.12
	# Checking out to the commit and Building
	cp build-artifacts/starkgate-contracts-82e651f/foundry.toml lib/starkgate-contracts-82e651f/src/starkware/foundry.toml
	cd lib/starkgate-contracts-82e651f && \
	git checkout $(STARKGATE_LEGACY_CONTRACTS_COMMIT_HASH) && \
	cd src/starkware && \
	forge build
	# Copying Contracts
	cp lib/starkgate-contracts-82e651f/src/starkware/out/StarknetEthBridge.sol/StarknetEthBridge.json artifacts/starkgate-contracts-0.9/StarknetLegacyBridge.json

l2-artifacts:
	make cairo-lang
	make local-contracts
	make starkgate-contracts-latest
	make starkgate-contracts-old
	make starkgate-contracts-82e651f
	python3 build-artifacts/convert.py
	echo "L2 Artifacts built ✅"

ARTIFACTS := "./build_artifacts"

# dim white italic
DIM            := \033[2;3;37m

# bold cyan
INFO           := \033[1;36m

# bold green
PASS           := \033[1;32m

# bold red
WARN           := \033[1;31m

RESET          := \033[0m

.PHONY: artifacts
artifacts:
	@if [ -d "$(ARTIFACTS)/starkgate_4594188" ] || \
		[ -d "$(ARTIFACTS)/starkgate_c08863a" ] || \
		[ -d "$(ARTIFACTS)/starkgate_82e651f" ] || \
		[ -d "$(ARTIFACTS)/cairo_lang"        ] || \
		[ -d "$(ARTIFACTS)/piltover"          ] || \
		[ -d "$(ARTIFACTS)/local_contracts"   ]; \
	then \
		echo -e "$(DIM)Build artifacts have already been generated, do you want to overwrite them?$(RESET) $(PASS)[y/N] $(RESET)" && \
			read ans && \
			case "$$ans" in \
				[yY]*) true;; \
			*) false;; \
		esac \
	fi
	@echo -e "$(WARN)Removing existing artifacts$(RESET)"
	@rm -rf $(ARTIFACTS)/starkgate_4594188
	@rm -rf $(ARTIFACTS)/starkgate_c08863a
	@rm -rf $(ARTIFACTS)/starkgate_82e651f
	@rm -rf $(ARTIFACTS)/cairo_lang
	@rm -rf $(ARTIFACTS)/piltover
	@rm -rf $(ARTIFACTS)/local_contracts
	@docker build -f ./build_artifacts/Dockerfile -t contracts .
	@docker create --name contracts contracts do-nothing > /dev/null
	@docker cp contracts:/artifacts/. ./build_artifacts/
	@docker rm contracts > /dev/null

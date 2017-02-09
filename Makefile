default:
	nix-build -I nixpkgs=https://github.com/mayflower/nixpkgs/archive/master.tar.gz
	@echo "Run ./result/bin/run-testgw-vm to launch the test gateway!"

.PHONY: default

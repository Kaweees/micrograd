# Like GNU `make`, but `just` rustier.
# https://just.systems/
# run `just` from this directory to see available commands

alias b := build
alias r := run
alias t := test
alias c := clean
alias f := format
alias d := docs

# Default command when 'just' is run without arguments
default:
  @just --list

# Get the number of cores
CORES := if os() == "macos" { `sysctl -n hw.ncpu` } else if os() == "linux" { `nproc` } else { "1" }

# Build the project
build:
  @echo "Building..."
  @zig build

# Run a package
run:
  @echo "Running..."
  @zig build run

# Test the project
test:
  @echo "Testing..."
  @zig build test

# Remove build artifacts and non-essential files
clean:
  @echo "Cleaning..."
  @rm -rf .zig-cache zig-out

# Format the project
format:
  @echo "Formatting..."
  @zig fmt .
  @nixfmt .

# Generate documentation
docs:
  @echo "Generating documentation..."
  @zig build docs

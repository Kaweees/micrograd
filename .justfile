# Like GNU `make`, but `just` rustier.
# https://just.systems/
# run `just` from this directory to see available commands

alias r := run
alias b := build
alias c := clean
alias f := format
alias d := docs

# Default command when 'just' is run without arguments
default:
  @just --list

# Get the number of cores
CORES := if os() == "macos" { `sysctl -n hw.ncpu` } else if os() == "linux" { `nproc` } else { "1" }

# Run a package
run:
  @echo "Running..."
  @zig build run

# Build the project
build:
  @echo "Building..."
  @zig build

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

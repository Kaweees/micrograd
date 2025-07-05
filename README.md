<!-- PROJECT SHIELDS -->
<!--
*** I'm using markdown "reference style" links for readability.
*** Reference links are enclosed in brackets [ ] instead of parentheses ( ).
*** See the bottom of this document for the declaration of the reference variables
*** for contributors-url, forks-url, etc. This is an optional, concise syntax you may use.
*** https://www.markdownguide.org/basic-syntax/#reference-style-links
-->
<div align="left">

[![Contributors][contributors-shield]][contributors-url]
[![Forks][forks-shield]][forks-url]
[![Stargazers][stars-shield]][stars-url]

</div>

<a href="https://github.com/Kaweees/micrograd">
  <img alt="Zig Logo" src="assets/img/zig.svg" align="right" width="150">
</a>

<div align="left">
  <h1><em><a href="https://github.com/Kaweees/micrograd">~micrograd</a></em></h1>
</div>

<!-- ABOUT THE PROJECT -->

A Zig implementation of Karpathy's micrograd.

### Built With

[![Zig][Zig-shield]][Zig-url]
[![NixOS][NixOS-shield]][NixOS-url]
[![GitHub Actions][github-actions-shield]][github-actions-url]

<!-- PROJECT PREVIEW -->
## Preview

<p align="center">
  <img src="assets/img/demo.mp4"
  width = "80%"
  alt = "Video demonstration"
  />
</p>

<!-- GETTING STARTED -->
## Getting Started

### Prerequisites

Before attempting to build this project, make sure you have [Nix](https://nixos.org/download.html) with [Flake](https://nixos.wiki/wiki/Flakes) support installed on your machine.

### Installation

To get a local copy of the project up and running on your machine, follow these simple steps:

1. Clone the project repository

   ```sh
   git clone https://github.com/Kaweees/micrograd.git
   cd micrograd
   ```

2. Install the project dependencies

   ```sh
   nix-shell --max-jobs $(nproc) # Linux / Windows (WSL)
   nix-shell --max-jobs $(sysctl -n hw.ncpu) # macOS
   ```

3. Build the project

   ```sh
   just build
   ```

4. Run the project

   ```sh
   just run <package_name>
   ```

### Add as a dependency

To include `micrograd` in your Zig project, follow these steps:

1. Add to your `build.zig.zon` file via `zig fetch`:

   ```sh
   zig fetch --save git+https://github.com/Kaweees/micrograd.git
   ```

2. Add the following line to your `build.zig` file:

   ```zig
   const micrograd = @import("micrograd");

   pub fn build(b: *std.Build) void {
      // exe setup...

      const micrograd_dep = b.dependency("micrograd", .{
         .target = target,
         .optimize = optimize,
      });

      const micrograd_module = micrograd_dep.module("micrograd");
      exe.root_module.addImport("micrograd", micrograd_module);

      // additional build steps...
   }

   ```

## Usage

`micrograd` is designed to be easy to use. You can include the library in your Zig project by adding the following line to your source files:

```zig
const micrograd = @import("micrograd");
```

<!-- PROJECT FILE STRUCTURE -->
## Project Structure

```sh
micrograd/
├── .github/                       # GitHub Actions CI/CD workflows
├── src/                           # Library source files
│   ├── lib.zig                      # Public API entry point
│   └── ...
├── build.zig                      # Zig build script
├── build.zig.zon                  # Zig build script dependencies
├── LICENSE                        # Project license
└── README.md                      # You are here
```

## License

The source code for [Kaweees/micrograd](https://github.com/Kaweees/micrograd) is distributed under the terms of the MIT License, as I firmly believe that collaborating on free and open-source software fosters innovations that mutually and equitably beneficial to both collaborators and users alike. See [`LICENSE`](./LICENSE) for details and more information.

<!-- MARKDOWN LINKS & IMAGES -->
<!-- https://www.markdownguide.org/basic-syntax/#reference-style-links -->

[contributors-shield]: https://img.shields.io/github/contributors/Kaweees/micrograd.svg?style=for-the-badge
[contributors-url]: https://github.com/Kaweees/micrograd/graphs/contributors
[forks-shield]: https://img.shields.io/github/forks/Kaweees/micrograd.svg?style=for-the-badge
[forks-url]: https://github.com/Kaweees/micrograd/network/members
[stars-shield]: https://img.shields.io/github/stars/Kaweees/micrograd.svg?style=for-the-badge
[stars-url]: https://github.com/Kaweees/micrograd/stargazers

<!-- MARKDOWN SHIELD BAGDES & LINKS -->
<!-- https://github.com/Ileriayo/markdown-badges -->
[Zig-shield]: https://img.shields.io/badge/Zig-%f7a41d.svg?style=for-the-badge&logo=zig&logoColor=f7a41d&labelColor=222222&color=f7a41d
[NixOS-shield]: https://img.shields.io/badge/NIX-%23008080.svg?style=for-the-badge&logo=NixOS&logoColor=5277C3&labelColor=222222&color=5277C3
[NixOS-url]: https://nixos.org/
[Zig-url]: https://ziglang.org/
[github-actions-shield]: https://img.shields.io/badge/github%20actions-%232671E5.svg?style=for-the-badge&logo=githubactions&logoColor=2671E5&labelColor=222222&color=2671E5
[github-actions-url]: https://github.com/features/actions

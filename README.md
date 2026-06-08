# Gossamer Julia Code Formatter

Gossamer is a Julia code formatter which gives your code a gossamer
touch of perfection.

To be more precise it does enforce commonly agreed formatting
conventions like space after comma, space around most operators, and a
sane indentation. But it does not strive for maximal uniformity and
generally assumes that the developers, for the most part, know what
they are doing when they write their code. The idea is to fix
mistakes, not to completely re-format the code or destroy carefully
made code layouts.

## Alternatives

If code uniformity is your primary goal, you are probably better
served by [Runic](https://github.com/fredrikekre/Runic.jl) or
[JuliaFormatter](https://github.com/JuliaEditorSupport/JuliaFormatter.jl),
where the former is intentionally not configurable and the latter
provides configurability and line-length sensitive formatting.

## Installation

Gossamer requires Julia 1.12 or later and is intended to be run as a
command line interface. Install the `gossamer` command line interface
with

```
using Pkg
Pkg.Apps.add(url = "https://github.com/GunnarFarneback/Gossamer.jl.git")
```

As is common for Julia Apps, you also need to have `~/.julia/bin` in
your PATH.

## Usage

Run
```
gossamer --help
```
for usage instructions.

The command line interface is compatible with Runic and JuliaFormatter.

## Examples

Format a single file and write the output to terminal:

```
gossamer src/Gossamer.jl
```

Check what changes `gossamer` would make to all Julia source files in
a directory, shown as a git diff.

```
gossamer -cdv src
```

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
command line interface. Install it with

```
using Pkg
Pkg.Apps.add("Gossamer")
```

As is common for Julia Apps, you also need to have `~/.julia/bin` in
your PATH.

## Usage

The command line interface is compatible with Runic and
JuliaFormatter. For now, see their documentation.

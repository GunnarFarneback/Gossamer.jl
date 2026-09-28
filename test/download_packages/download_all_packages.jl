using RegistryInstances: reachable_registries, registry_info
using CodecZlib: GzipDecompressorStream
import Downloads
import Tar

# Download the latest version of all registered packages, but only
# keep julia files and top level (Julia)Project.toml files.
function download_all_packages(target_dir = joinpath(@__DIR__, "../packages");
                               interval = 5, verbose = true)
    mkpath(target_dir)
    registries = reachable_registries()
    for registry in registries
        n = length(registry.pkgs)
        for (i, uuid) in enumerate(sort(collect(keys(registry.pkgs))))
            package = registry.pkgs[uuid]
            endswith(package.name, "_jll") && continue
            verbose && print(lpad("\r$(lpad(i, ndigits(n)))/$(n) $(uuid) $(package.name)", 80))
            target = joinpath(target_dir, package.name)
            if ispath(target)
                verbose && println(" already downloaded, skipped.")
                continue
            end
            pkg = registry_info(package)
            versions = keys(pkg.version_info)
            latest_version = maximum(versions)
            treehash = string(pkg.version_info[latest_version].git_tree_sha1)
            if registry.name == "General"
                server = "https://pkg.julialang.org"
            else
                server = ENV["JULIA_PKG_SERVER"]
                if !startswith(server, "https://")
                    server = "https://" * server
                end
            end
            url = "$server/package/$uuid/$treehash"
            tarball = ""
            try
                tarball = Downloads.download(url)
            catch e
                if e isa Downloads.RequestError
                    verbose && println(" download error")
                    verbose || println("$(uuid) $(package.name) download error")
                else
                    rethrow()
                end
            end
            isempty(tarball) && continue
            open(tarball) do io
                Tar.extract(file_filter, GzipDecompressorStream(io), target)
            end
            rm(tarball)
            sleep(interval)
        end
    end
end

function file_filter(header)
    header.type == :file || return false
    header.path in ("Project.toml", "JuliaProject.toml") && return true
    endswith(header.path, ".jl") || return false
    # Catch some files in the Pigeons package, which are actually
    # serialization files and ought to have .jls extension rather than
    # .jl extension.
    contains(header.path, "SR1_M87_2017_096_lo_hops_netcal_StokesI.uvfits") && return false
    return true
end

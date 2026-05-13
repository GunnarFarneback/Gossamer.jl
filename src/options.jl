using OptParse

const parser = object((check = flag("-c", "--check"),
                       diff = flag("-d", "--diff"),
                       inplace = flag("-i", "--inplace"),
                       lines = multiple(option("--lines",
                                               str("LINES",
                                                   pattern = r"^\d+:\d+$"))),
                       output = optional(option(("-o", "--output"),
                                                str("OUTPUT"))),
                       stdin_filename = optional(option("--stdin-filename",
                                                        str("STDIN-FILENAME"))),
                       verbose = flag("-v", "--verbose"),
                       version = flag("--version"),
                       files = multiple(arg(str("FILE")))))

function parse_options(args)
    return argparse(parser, args)
end

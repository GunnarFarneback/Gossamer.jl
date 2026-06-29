using OptParse

const parser = record((check = flag("-c", "--check"),
                       diff = flag("-d", "--diff"),
                       help = flag("-h", "--help"),
                       inplace = flag("-i", "--inplace"),
                       lines = many(option("--lines", str("LINES"))),
                       output = optional(option(("-o", "--output"),
                                                str("OUTPUT"))),
                       stdin_filename = optional(option("--stdin-filename",
                                                        str("STDIN-FILENAME"))),
                       verbose = flag("-v", "--verbose"),
                       version = flag("--version"),
                       files = many(arg(str("FILE")))))

function parse_options(args)
    return optparse(parser, args)
end

const usage_help =
"""
usage: gossamer [options] <path>...

NAME
       gossamer - format Julia source code

SYNOPSIS
       gossamer [<options>] <path>...

DESCRIPTION

       gossamer formats Julia source code with a focus on fixing mistakes rather
       than enforcing a uniform style.

OPTIONS
       <path>...
           Input path(s) (files and/or directories) to process. For directories,
           all files (recursively) with the '.jl' extension are used as input
           files. If no path is given, or if path is `-`, input is read from stdin.

       -c, --check
           Do not write output and exit with a non-zero code if the input is not
           formatted correctly.

       -d, --diff
           Print the diff between the input and formatted output to stderr.
           Requires `git` to be installed.

       -h, --help
           Print this message.

       -i, --inplace
           Format files in place.

       --lines=<start line>:<end line>
           Limit formatting to the line range <start line> to <end line>. Multiple
           ranges can be formatted by specifying multiple --lines arguments.

       -o <file>, --output=<file>
           File to write formatted output to. If no output is given, or if the file
           is `-`, output is written to stdout.

       --stdin-filename=<filename>
           Assumed filename when formatting from stdin. Used for error messages.

       -v, --verbose
           Enable verbose output.

       --version
           Print Gossamer and julia version information.
"""

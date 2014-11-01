package Perinci::CmdLine::Util;

our $DATE = '2014-11-01'; # DATE
our $VERSION = '0.02'; # VERSION

use 5.010001;
use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(detect_perinci_cmdline_script);

our %SPEC;

$SPEC{detect_perinci_cmdline_script} = {
    v => 1.1,
    summary => 'Detect whether a file is a Perinci::CmdLine-based CLI script',
    description => <<'_',

The criteria are:

* the file must exist and readable;

* (optional, if `include_noexec` is false) file must have its executable mode
  bit set;

* content must start with a shebang C<#!>;

* either: must be perl script (shebang line contains 'perl') and must contain
  something like `use Perinci::CmdLine`;

* or: a script tagged as a wrapper script and the wrapped script is a
  Perinci::CmdLine script.

_
    args => {
        script => {
            summary => 'Path to file to be checked',
            req => 1,
            pos => 0,
        },
        include_noexec => {
            summary => 'Include scripts that do not have +x mode bit set',
            schema  => 'bool*',
            default => 1,
        },
        include_backup => {
            summary => 'Include backup files',
            schema  => 'bool*',
            default => 0,
        },
        include_wrapper => {
            summary => 'Include wrapper scripts',
            description => <<'_',

A wrapper script is another Perl script, a shell script, or some other script
which wraps a Perinci::CmdLine script. For example, if `list-id-holidays` is a
Perinci::CmdLine script, then this shell script called `list-id-joint-leaves` is
a wrapper:

    #!/bin/bash
    list-id-holidays --is-holiday=0 --is-joint-leave=0 "$@"

It makes sense to provide the same completion for this wrapper script as
`list-id-holidays`.

To help this function detect such script, you need to put a tag inside the file:

    #!/bin/bash
    # TAG wrapped=list-id-holidays
    list-id-holidays --is-holiday=0 --is-joint-leave=0 "$@"

If this option is enabled, these scripts will be included.

_
            schema  => 'bool*',
            default => 0,
        },
    },
};
sub detect_perinci_cmdline_script {
    my %args = @_;

    my $script = $args{script} or return [400, "Please specify script"];
    my $include_noexec  = $args{include_noexec}  // 1;
    my $include_backup  = $args{include_backup}  // 0;
    my $include_wrapper = $args{include_wrapper} // 0;

    my $yesno = 0;
    my $reason = "";

  DETECT:
    {
        if (!$include_backup && $script =~ /(~|\.bak)$/) {
            $reason = "Backup filename is excluded";
            last;
        }
        unless (-f $script) {
            $reason = "Not a file";
            last;
        };
        if ($args{filter_x} && !(-x _)) {
            $reason = "Not an executable";
            last;
        }
        my $fh;
        unless (open $fh, "<", $script) {
            $reason = "Can't be read";
            last;
        }
        read $fh, my($buf), 2;
        unless ($buf eq '#!') {
            $reason = "Does not start with a shebang (#!) sequence";
            last;
        }
        my $shebang = <$fh>;

        for my $alt (1..2) {
            # detect Perinci::CmdLine script
            {
                last unless $alt==1;
                unless ($shebang =~ /perl/) {
                    $reason = "Does not have 'perl' in the shebang line";
                    last;
                }
                while (<$fh>) {
                    if (/^\s*(use|require)\s+Perinci::CmdLine(|::Any|::Lite)/) {
                        $yesno = 1;
                        last DETECT;
                    }
                }
                $reason = "Can't find any statement requiring Perinci::CmdLine".
                    " module family";
            }
            # detect wrapper script
          DETECT_WRAPPER:
            {
                last unless $alt==2;
                last unless $include_wrapper;
                seek $fh, 0, 0;
                # XXX currently simplistic
                while (<$fh>) {
                    if (/^# TAG wrapped=([^=\s]+)\s*$/) {
                        require File::Which;
                        my $path = File::Which::which($1);
                        if (!$path) {
                            $reason = "Tagged as wrapper but ".
                                "wrapped program '$1' not found in PATH";
                            last DETECT_WRAPPER;
                        }
                        my $res = detect_perinci_cmdline_script(
                            script          => $path,
                            include_backup  => $include_backup,
                            include_noexec  => $include_noexec,
                            include_wrapper => 0, # currently not recursive
                        );
                        if ($res->[0] != 200 || !$res->[2]) {
                            $reason = "Tagged as wrapper but wrapped program ".
                                "'$1' is not a Perinci::CmdLine script";
                        }
                        $yesno = 1;
                        $reason = "Wrapper script for '$1'";
                        last DETECT;
                    }
                }
                $reason = "Can't find wrapper tag";
            }
        } # for alt
    }

    [200, "OK", $yesno, {"func.reason"=>$reason}];
}

1;
# ABSTRACT: Utility routines related to Perinci::CmdLine

__END__

=pod

=encoding UTF-8

=head1 NAME

Perinci::CmdLine::Util - Utility routines related to Perinci::CmdLine

=head1 VERSION

This document describes version 0.02 of Perinci::CmdLine::Util (from Perl distribution Perinci-CmdLine-Util), released on 2014-11-01.

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 FUNCTIONS


=head2 detect_perinci_cmdline_script(%args) -> [status, msg, result, meta]

Detect whether a file is a Perinci::CmdLine-based CLI script.

The criteria are:

=over

=item * the file must exist and readable;

=item * (optional, if C<include_noexec> is false) file must have its executable mode
bit set;

=item * content must start with a shebang C<#!>;

=item * either: must be perl script (shebang line contains 'perl') and must contain
something like C<use Perinci::CmdLine>;

=item * or: a script tagged as a wrapper script and the wrapped script is a
Perinci::CmdLine script.

=back

Arguments ('*' denotes required arguments):

=over 4

=item * B<include_backup> => I<bool> (default: 0)

Include backup files.

=item * B<include_noexec> => I<bool> (default: 1)

Include scripts that do not have +x mode bit set.

=item * B<include_wrapper> => I<bool> (default: 0)

Include wrapper scripts.

A wrapper script is another Perl script, a shell script, or some other script
which wraps a Perinci::CmdLine script. For example, if C<list-id-holidays> is a
Perinci::CmdLine script, then this shell script called C<list-id-joint-leaves> is
a wrapper:

 #!/bin/bash
 list-id-holidays --is-holiday=0 --is-joint-leave=0 "$@"

It makes sense to provide the same completion for this wrapper script as
C<list-id-holidays>.

To help this function detect such script, you need to put a tag inside the file:

 #!/bin/bash
 # TAG wrapped=list-id-holidays
 list-id-holidays --is-holiday=0 --is-joint-leave=0 "$@"

If this option is enabled, these scripts will be included.

=item * B<script>* => I<any>

Path to file to be checked.

=back

Return value:

Returns an enveloped result (an array).

First element (status) is an integer containing HTTP status code
(200 means OK, 4xx caller error, 5xx function error). Second element
(msg) is a string containing error message, or 'OK' if status is
200. Third element (result) is optional, the actual result. Fourth
element (meta) is called result metadata and is optional, a hash
that contains extra information.

 (any)

=for Pod::Coverage ^(new)$

=head1 SEE ALSO

L<Perinci::CmdLine>

=head1 HOMEPAGE

Please visit the project's homepage at L<https://metacpan.org/release/Perinci-CmdLine-Util>.

=head1 SOURCE

Source repository is at L<https://github.com/perlancar/perl-Perinci-CmdLine-Util>.

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website L<https://rt.cpan.org/Public/Dist/Display.html?Name=Perinci-CmdLine-Util>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=head1 AUTHOR

perlancar <perlancar@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by perlancar@cpan.org.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

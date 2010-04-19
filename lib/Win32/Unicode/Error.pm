package Win32::Unicode::Error;

use strict;
use warnings;
use 5.008003;
use Win32::API ();
use Carp ();
use Exporter 'import';

our $VERSION = '0.18';

use Errno qw[
    ERROR_FILE_EXISTS
    :POSIX
];

use Win32::Unicode::Constant;
use Win32::Unicode::Util;
use Win32::Unicode::Define;

# export subs
our @EXPORT    = qw/errorW/;
our @EXPORT_OK = qw/error/;
our %EXPORT_TAGS = ('all' => [@EXPORT, @EXPORT_OK]);

my %ERROR_TABLE = (
    &ERROR_FILE_EXISTS => EEXIST,
);

sub errorW {
    my $buff = BUFF;
    my $result = FormatMessage->Call(
        FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS,
        NULL,
        GetLastError->Call,
        LANG_USER_DEFAULT,
        $buff,
        length($buff),
        NULL,
    );
    
    $buff = unpack "A520", $buff;
    return utf16_to_utf8($buff);
}

sub _set_errno {
    my $errno = GetLastError->Call;
    $! = $ERROR_TABLE{$errno} || $errno;
    return;
}

*error = *errorW;

1;
__END__
=head1 NAME

Win32::Unicode::Error.pm - return error message.


=head1 SYNOPSIS

  use Win32::Unicode;
  
  # stdout unicode string
  mkdirW($exists_dir) or die errorW
  
=head1 DESCRIPTION

Wn32::Unicode::Error is retrun to Win32API error message.

=head1 FUNCTIONS

=over

=item errorW

function.

=back

=head1 AUTHOR

Yuji Shimada E<lt>xaicron@gmail.comE<gt>

=head1 SEE ALSO

L<Win32::Unicode>
L<Win32::Unicode::Dir>
L<Win32::Unicode::File>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

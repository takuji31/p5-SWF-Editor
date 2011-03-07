package  SWF::Editor::Utils::Header;
use strict;
use warnings;

use Exporter::Lite;

our @EXPORT = qw/
    create_long_header
    create_header
    is_long_header
/;

#create tag header (long type)
sub create_long_header {
    create_header( $_[0], 63 );
}
#create tag header (short type)
sub create_header {
    my ( $type, $length ) = @_;
    return $type << 6 | $length;
}

sub is_long_header {
    return ( $_[0] & 0x3f ) == 0x3f ? 1 : 0;
}

1;


package SWF::Editor::Utils::IOBit;
use Mouse;

=pod

=encoding utf8

=head1 NAME

SWF::Editor::Utils::IOBit - Bit steam IO utility

=head1 DESCRIPTION

Referred to the following libraries.

http://openpear.org/package/IO_Bit

=cut

has 'data' => ( is => 'rw', isa => 'Str', default => '' );
has 'byte_offset' => ( is => 'rw', isa => 'Int', default => 0 );
has 'bit_offset'  => ( is => 'rw', isa => 'Int', default => 0 );

sub input {
    my ( $self, $data ) = @_;
    $self->data($data);
    $self->byte_offset(0);
    $self->bit_offset(0);
}

sub output {
    my ( $self, $offset ) = shift;
    $offset = 0 unless defined $offset;
    my $output_len = $self->byte_offset;
    if ($self->bit_offset > 0) {
        $output_len++;
    }
    if (length ($self->data) == $output_len) {
        return $self->data;
    }
    return substr($self->data, $offset, $output_len);
}

sub add_byte_offset {
    my ($self, $val ) = @_;
    $self->byte_offset( $self->byte_offset + $val );
}

sub add_bit_offset {
    my ($self, $val ) = @_;
    $val += $self->bit_offset;
    my $bit = $val % 8;
    my $byte = ($val - $bit) / 8;
    $self->bit_offset($bit);
    $self->add_byte_offset($byte);
}

sub set_offset {
    my ( $self, $byte_offset, $bit_offset ) = @_;
    $self->byte_offset($byte_offset);
    $self->bit_offset($bit_offset);
}

sub increment_offset {
    my ($self, $byte_offset, $bit_offset) = @_;
    $self->add_byte_offset($byte_offset);
    $self->add_bit_offset($bit_offset);
    while ( $self->bit_offset >= 8 ) {
        $self->add_byte_offset(1);
        $self->add_bit_offset(-8);
    }
    while ( $self->bit_offset < 0 ) {
        $self->add_byte_offset(-1);
        $self->add_bit_offset(8);
    }
}

sub get_offset {
    my $self = shift;
    return ( $self->byte_offset, $self->bit_offset );
}

sub byte_align {
    my $self = shift;
    if ( $self->bit_offset > 0 ) {
        $self->add_byte_offset(1);
        $self->bit_offset(0);
    }
}

sub get_data {
    my ( $self, $len ) = @_;
    $self->byte_align;
    my $data = substr $self->data, $self->byte_offset, $len;
    my $data_len = length $data;
    $self->add_byte_offset($data_len);
    return $data;
}

sub get_ui8 {
    my $self = shift;
    $self->byte_align;
    my $value = ord( substr $self->data, $self->byte_offset, 1 );
    $self->add_byte_offset(1);
    return $value;
}

sub get_ui16_be {
    my $self = shift;
    $self->byte_align;
    my @ret = unpack( 'n', substr $self->data, $self->byte_offset, 2 );
    $self->add_byte_offset(2);
    return $ret[0];
}

sub get_ui32_be {
    my $self = shift;
    $self->byte_align;
    my @ret = unpack( 'N', substr $self->data, $self->byte_offset, 4 );
    $self->add_byte_offset(4);
    return $ret[0];
}

sub get_ui16_le {
    my $self = shift;
    $self->byte_align;
    my @ret = unpack( 'v', substr $self->data, $self->byte_offset, 2 );
    $self->add_byte_offset(2);
    return $ret[0];
}

sub get_ui32_le {
    my $self = shift;
    $self->byte_align;
    my @ret = unpack( 'V', substr $self->data, $self->byte_offset, 4 );
    $self->add_byte_offset(4);
    return $ret[0];
}

sub get_ui_bit {
    my $self = shift;
    my $value = ord( substr $self->data, $self->byte_offset, 1 );
    $value = 1 & ( $value >> ( 7 - $self->bit_offset ) );
    $self->add_bit_offset(1);
    if ( 8 <= $self->bit_offset ) {
        $self->add_byte_offset(1);
        $self->bit_offset(0);
    }
    return $value;
}

sub get_ui_bits {
    my ( $self, $width ) = @_;
    my $value = 0;
    for ( my $i = 0; $i < $width; $i++ ) {
        $value <<= 1;
        $value |=  $self->get_ui_bit;
    }
    return $value;
}

sub get_si_bits {
    my ( $self, $width ) = @_;
    my $value = $self->get_ui_bits($width);
    my $msb   = $value & ( 1 << ( $width - 1 ) );
    if ($msb) {
        my $bitmask = ( 2 * $msb ) - 1;
        $value = - ( $value ^ $bitmask ) - 1;
    }
    return $value;
}

sub add_data {
    my ( $self, $data ) = @_;
    $self->data( $self->data . $data );
}

sub put_data {
    my ( $self, $data ) = @_;
    $self->byte_align;
    $self->add_data($data);
    $self->add_byte_offset(length $data);
}

sub put_ui8 {
    my ( $self, $value ) = @_;
    $self->byte_align;
    $self->add_data(chr($value));
    $self->add_byte_offset(1);
}

sub put_ui16_be {
    my ( $self, $value ) = @_;
    $self->byte_align;
    $self->add_data( pack ( 'n', $value ) );
    $self->add_byte_offset(2);
}

sub put_ui32_be {
 my ( $self, $value ) = @_;
    $self->byte_align;
    $self->add_data( pack( 'N', $value ) );
    $self->add_byte_offset(4);
}

sub put_ui16_le {
 my ( $self, $value ) = @_;
    $self->byte_align;
    $self->add_data( pack( 'v', $value ) );
    $self->add_byte_offset(2);
}

sub put_ui32_le {
 my ( $self, $value ) = @_;
    $self->byte_align;
    $self->add_data( pack( 'V', $value ) );
    $self->add_byte_offset(4);
}

sub alloc_data {
 my ( $self, $need_data_len ) = @_;
    unless (defined $need_data_len) {
        $need_data_len = $self->byte_offset;
    }
    my $data_len = length $self->data;
    if ($data_len < $need_data_len) {
        my $pack_len = $need_data_len - $data_len;
        $self->add_data( pack( "a$pack_len", chr(0) ) );
    }
}

sub put_ui_bit {
 my ( $self, $bit ) = @_;
    $self->alloc_data($self->byte_offset + 1);
    if ( $bit > 0 ) {
        my $value = ord( substr $self->data, $self->byte_offset, 1 );
        $value |= 1 << ( 7 - $self->bit_offset );
        my $data = $self->data;
        substr $data, $self->byte_offset, 1, chr($value);
        $self->data($data);
    }
    $self->add_bit_offset(1);
    if ( 8 <= $self->bit_offset ) {
        $self->add_byte_offset(1);
        $self->bit_offset(0);
    }
}

sub put_ui_bits {
 my ( $self, $value, $width ) = @_;
    for (my $i = $width - 1 ; $i >= 0 ; $i--) {
        my $bit = ($value >> $i) & 1;
        $self->put_ui_bit($bit);
    }
}

sub put_si_bits {
 my ( $self, $value, $width ) = @_;
    if ($value < 0) {
        my $msb = 1 << ($width - 1);
        my $bitmask = (2 * $msb) - 1;
        $value = (-$value  - 1) ^ $bitmask;
    }
    $self->put_ui_bits($value, $width);
}

sub set_ui32_le {
    my ( $self, $value, $byte_offset ) = @_;
    my $pack_data = pack('V', $value);
    my @packchars = split //, $pack_data;

    my $data = $self->data;
    for my $i ( 0 .. 3 ) {
        substr $data, $byte_offset + $i, 1, $packchars[$i];
    }
    $self->data($data);
}

sub need_bits_unsigned {
    my ( $self, $n ) = @_;
    my $i;
    for ( $i = 0; $n; $i++ ) {
        $n >>= 1;
    }
    return $i;
}
sub need_bits_signed {
    my ( $self, $n ) = @_;
    my $ret;
    if ($n < -1) {
        $n = -1 - $n;
    }
    if ($n >= 0) {
        my $i;
        for ( $i = 0 ; $n ; $i++) {
            $n >>= 1;
        }
        $ret = 1 + $i;
    } else {
        $ret = 1;
    }
    return $ret;
}

1;

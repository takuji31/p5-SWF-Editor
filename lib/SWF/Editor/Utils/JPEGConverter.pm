package  SWF::Editor::Utils::JPEGConverter;
use Mouse;

use SWF::Editor::Utils::IOBit;
use Digest::MD5 qw/ md5_hex /;

has 'data'  => ( is => 'rw', isa => 'Str' );
has 'chunk' => ( is => 'rw', isa => 'ArrayRef', default => sub{ +[] } );

our $marker_name_table = {
    0xD8 => 'SOI',
    0xE0 => 'APP0',  0xE1 => 'APP1',  0xE2 => 'APP2',  0xE3 => 'APP3',
    0xE4 => 'APP4',  0xE5 => 'APP5',  0xE6 => 'APP6',  0xE7 => 'APP7',
    0xE8 => 'APP8',  0xE9 => 'APP9',  0xEA => 'APP10', 0xEB => 'APP11',
    0xEC => 'APP12', 0xED => 'APP13', 0xEE => 'APP14', 0xEF => 'APP15',
    0xFE => 'COM',
    0xDB => 'DQT',
    0xC0 => 'SOF0', 0xC1 => 'SOF1',  0xC2 => 'SOF2',  0xC3 => 'SOF3',
    0xC5 => 'SOF5', 0xC6 => 'SOF6',  0xC7 => 'SOF7',
    0xC8 => 'JPG',  0xC9 => 'SOF9',  0xCA => 'SOF10', 0xCB => 'SOF11',
    0xCC => 'DAC',  0xCD => 'SOF13', 0xCE => 'SOF14', 0xCF => 'SOF15',
    0xC4 => 'DHT',
    0xDA => 'SOS',
    0xD0 => 'RST0', 0xD1 => 'RST1', 0xD2 => 'RST2', 0xD3 => 'RST3',
    0xD4 => 'RST4', 0xD5 => 'RST5', 0xD6 => 'RST6', 0xD7 => 'RST7',
    0xDD => 'DRI',
    0xD9 => 'EOI',
    0xDC => 'DNL',   0xDE => 'DHP',  0xDF => 'EXP',
    0xF0 => 'JPG0',  0xF1 => 'JPG1', 0xF2 => 'JPG2',  0xF3 => 'JPG3',
    0xF4 => 'JPG4',  0xF5 => 'JPG5', 0xF6 => 'JPG6',  0xF7 => 'JPG7',
    0xF8 => 'JPG8',  0xF9 => 'JPG9', 0xFA => 'JPG10', 0xFB => 'JPG11',
    0xFC => 'JPG12', 0xFD => 'JPG13'
};

sub split_chunk {
    my $self = shift;
    my $bitin = SWF::Editor::Utils::IOBit->new( data => $self->data );
    SPLIT_CHUNK: while ( my $marker1 = $bitin->get_ui8 ) {
        if ($marker1 != 0xFF) {
            warn $marker1;
            warn sprintf("dumpChunk: marker1=0x%02X at %02x(%02d)", $marker1, $bitin->byte_offset,$bitin->byte_offset);
            return;
        }
        my $marker2 = $bitin->get_ui8;
        if ( $marker2 ==  0xD8 ) { 
            # SOI (Start of Image)
            push @{$self->chunk},{ marker => $marker2 };
            next SPLIT_CHUNK;
        }
        elsif ( $marker2 == 0xD9 ) {
            # EOE (End of Image)
            push @{$self->chunk},{ marker => $marker2 };
            last SPLIT_CHUNK;
        }
        elsif ( scalar grep { $marker2 == $_ } ( 0xDA, 0xD0, 0xD1, 0xD2, 0xD3, 0xD4,  0xD5, 0xD6, 0xD7 ) ) {
            # RST
            my $chunk_data_offset = $bitin->byte_offset;
            RST: while (1) {
                my $next_marker1 = $bitin->get_ui8;
                if ( $next_marker1 != 0xFF ) {
                    next RST;
                }
                my $next_marker2 = $bitin->get_ui8;
                if ( $next_marker2 == 0x00 ) {
                    next RST;
                }
                $bitin->increment_offset(-2, 0); # back from next marker
                my $next_chunk_offset = $bitin->byte_offset;
                my $length = $next_chunk_offset - $chunk_data_offset;
                $bitin->set_offset($chunk_data_offset, 0);
                push @{$self->chunk}, { marker => $marker2, data => $bitin->get_data($length) };
                last RST;
            }
            next SPLIT_CHUNK;
        } else {
            my $length = $bitin->get_ui16_be;
            push @{$self->chunk}, { marker => $marker2, data => $bitin->get_data($length - 2), length => $length };
            next SPLIT_CHUNK;
        }
    }
}
# from: SOI APP* DQT SOF* DHT SOS EOI
# to:  SOI APP* SOF* SOS EOI
sub get_image_data {
    my ( $self,  ) = @_;
    if ( scalar @{$self->chunk} == 0 ) {
        $self->split_chunk;
    }
    my $bitout =  SWF::Editor::Utils::IOBit->new;
    for my $chunk (@{$self->chunk}) {
        my $marker = $chunk->{marker};
        if (($marker == 0xDB) || ($marker == 0xC4)) {
            next;  # skip DQT(0xDB) or DHT(0xC4)
        }
        $bitout->put_ui8(0xFF);
        $bitout->put_ui8($marker);
        if ( defined $chunk->{data} ) { # not ( SOI or EOI )
            if ( defined $chunk->{length} ) {
                $bitout->put_ui16_be( $chunk->{length} );
            }
            $bitout->put_data($chunk->{data});
        }
    }
    return $bitout->output;
}
# from: SOI APP* DQT SOF* DHT SOS EOI
# to:   SOI DQT DHT EOI
sub get_encoding_tables {
    my $self = shift;
    if ( scalar @{$self->chunk} == 0 ) {
        $self->split_chunk;
    }
    my $bitout = SWF::Editor::Utils::IOBit->new;
    $bitout->put_ui8(0xFF);
    $bitout->put_ui8(0xD8); # SOI;
    for my $chunk (@{$self->chunk}) {
        my $marker = $chunk->{marker};
        if ( ($marker != 0xDB) && ($marker != 0xC4) ) {
            next;  # skip not ( DQT(0xDB) or DHT(0xC4) )
        }
        $bitout->put_ui8(0xFF);
        $bitout->put_ui8($marker);
        $bitout->put_ui16_be($chunk->{length});
        $bitout->put_data($chunk->{data});
    }
    $bitout->put_ui8(0xFF);
    $bitout->put_ui8(0xD9); # EOI;
    return $bitout->output;

}
sub dump_chunk {
    my $self = shift;
    if ( scalar @{$self->chunk} == 0 ) {
        $self->split_chunk;
    }
    for my $chunk (@{$self->chunk}) {
        my $marker = $chunk->{marker};
        my $marker_name = $marker_name_table->{$marker};
        unless ( defined $chunk->{data} ) {
            print "$marker_name:\n";
        } else {
            my $length = length $chunk->{data};
            my $md5 = md5_hex($chunk->{data});
            print "$marker_name: length=$length md5=$md5\n";
        }
    }
}

1;

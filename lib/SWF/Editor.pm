package SWF::Editor;
use strict;
use warnings;
use Mouse;
use Smart::Args;

use Compress::Zlib;
use SWF::Parser;
use SWF::BinStream;

use SWF::Editor::Tag;
use SWF::Editor::Tag::FrameLabel;
use SWF::Editor::Utils::Tag;
use SWF::Editor::Utils::Header;
use SWF::Editor::Utils::IOBit;


our $VERSION = '0.01';
=pod

=encoding utf8

=head1 NAME

SWF::Editor - SWF file editor

=head1 SYNOPSIS

  use strict;
  use warnings;
  use SWF::Editor;

  my $swf = SWF::Editor->new( file => '/path/to/file.swf' );
  $swf->insert_tag( 
    2 =>  SWF::Editor::Tag::DoAction::SetVariables->new(
              hoge => 'fuga',
              foo  => [qw/ bar baz/],
          )
  );
  $swf->get_binary;

=head1 DESCRIPTION

SWF::Editor is SWF file editor.

=head1 METHODS

=cut

our %HAS_CID_TAGS = (
    DefineBits         => 1,
    DefineBitsJPEG2    => 1,
    DefineBitsJPEG3    => 1,
    DefineBitsLossless => 1,
    DefineMorphShape   => 1,
    DefineShape        => 1,
    DefineShape2       => 1,
    DefineShape3       => 1,
    DefineText         => 1,
    DefineTextEdit     => 1,
    DefineEditText     => 1,
    DefineFont2        => 1,
    DefineSprite       => 1,
);


has compressed => (is => 'rw', isa => 'Bool', lazy_build => 1);
has file       => (is => 'ro', isa => 'Str');
has header     => (is => 'rw', isa => 'Str');
has raw_data   => (is => 'ro', isa => 'Value', lazy_build => 1);
has tags       => (is => 'rw',isa => 'ArrayRef[SWF::Editor::Tag]',default => sub { [] });
has frame_num_cache => ( is => 'rw', isa => 'HashRef[Int]', default => sub { +{} } );
has frame_label_cache => ( is => 'rw', isa => 'HashRef[Int]', default => sub { +{} } );

sub BUILD {
    my $self = shift;
    $self->parse;
}


sub _build_raw_data {
    my $self = shift;

    #Return undefined value, if filename doe's not exists.
    return unless $self->file;
    #Read swf file
    do {
        local $/;
        open(my $fh, "<", $self->file) or confess("Can't open swf file : ".$self->file);
        <$fh>
    };
}

sub parse {
    my $self = shift;

    my $raw = $self->raw_data;

    my $header_callback = sub {
        my $parser = shift;
        my ( $signature, $version, $length, $xmin, $ymin, $xmax, $ymax, $framerate, $framecount ) = @_;

        if ( substr($signature, 0, 1) eq 'C' ) {
            $self->compressed(1);
        } else {
            $self->compressed(0);
        }
        my $nbits = SWF::BinStream::Write::get_maxbits_of_sbits_list($xmin, $ymin, $xmax, $ymax);
        my $rect_bit = join("",
            substr(unpack("B*", pack("N", $nbits)), -5),
            substr(unpack("B*", pack("N", $xmin)), -$nbits),
            substr(unpack("B*", pack("N", $xmax)), -$nbits),
            substr(unpack("B*", pack("N", $ymin)), -$nbits),
            substr(unpack("B*", pack("N", $ymax)), -$nbits),
        );

        my $binary = pack("A3CVB*vv", $signature, $version, $length, $rect_bit, $framerate*256, $framecount);
        $self->header( $binary );
    };

    my @tags = ();
    my $frame_num = 1;
    my $tag_callback = sub {
        my ( $parser, $type, $length, $datastream ) = @_;

        my $header = $parser->{_tag}{header};
        my $data   = $datastream->get_string($length);

        my $pos = scalar @tags;
        if ( compare_tag_number($type, 'ShowFrame') ) {
            #cache frame number
            $self->frame_num_cache->{$frame_num} = $pos;
            $frame_num++;
        }
        if ( compare_tag_number($type, 'FrameLabel') ) {
            my $ftag = SWF::Editor::Tag::FrameLabel->new(data => $data);
            my $flabel = $ftag->name;
            $self->frame_label_cache->{$flabel} = $pos;
            push @tags, $ftag;
            return;
        }

        push @tags, SWF::Editor::Tag->new(
            header => $header,
            type   => $type,
            length => $length,
            data   => $data,
        );
    };

    my $parser = SWF::Parser->new(
        'header-callback' => $header_callback,
        'tag-callback'    => $tag_callback,
    );
    $parser->parse($raw);
    $self->tags(\@tags);

}

sub insert_tag {
    args_pos my $self,
             my $pos => { isa => 'Int' },
             my $tag => { isa => 'SWF::Editor::Tag' };

    splice @{$self->tags}, $pos,0,$tag;

    $self->refresh_caches($pos);
    return $self;
}

sub replace_tag {
    args_pos my $self,
             my $pos => { isa => 'Int' },
             my $tag => { isa => 'SWF::Editor::Tag' },
             my $replace_cid => { isa => 'Bool', default => 0};

    my $old_tag = $self->tags->[$pos];
    $self->tags->[$pos] = $tag;
    if( $replace_cid ) {
        $tag->cid($old_tag->cid);
    }
    return $self;
}

sub refresh_caches {
    args_pos my $self,
             my $pos  => { isa => 'Int' };
    for my $frame_num ( keys %{$self->frame_num_cache} ) {
        my $old_pos = $self->frame_num_cache->{$frame_num};
        if ( $old_pos >= $pos ) {
            $self->frame_num_cache->{$frame_num}++;
        }
    }
    for my $label ( keys %{$self->frame_label_cache} ) {
        my $old_pos = $self->frame_label_cache->{$label};
        if ( $old_pos >= $pos ) {
            $self->frame_label_cache->{$label}++;
        }
    }
    return $self;
}

sub insert_tag_by_frame_no {
    args_pos my $self,
             my $fnum => { isa => 'Int' },
             my $insert_tag  => { isa => 'SWF::Editor::Tag' };

    my $pos = $self->frame_num_cache->{$fnum};
    unless ( defined $pos ) {
        confess("Frame number $fnum does not exists!");
    }
    $self->insert_tag($pos => $insert_tag);
    return $self;
}

sub insert_tag_after_label {
    args_pos my $self,
             my $label => { isa => 'Int' },
             my $insert_tag   => { isa => 'SWF::Editor::Tag' };

    my $pos = $self->frame_label_cache->{$label};

    unless ( defined $pos ) {
        confess("Frame label $label does not exists!");
    }

    $pos++;

    $self->insert_tag($pos => $insert_tag);
    return $self;

}


sub clone {
    my $self = shift;
    my $class = ref($self);
    #Clone array ref
    my $tags = [ map{ $_->clone } @{$self->tags} ];
    my $clone = $class->meta->clone_object($self);
    $clone->tags($tags);
    $clone->frame_num_cache({%{$self->frame_num_cache}});
    $clone->frame_label_cache({%{$self->frame_label_cache}});
    return $clone;
}

sub get_binary {
    my $self = shift;

    my @tags = @{ $self->tags };

    # rebuild data
    my $raw = join("", $self->header, map { $_->get_binary } @tags);
    # calculate data length
    substr( $raw, 4, 4, pack( "V", length($raw) ) );
    $raw;
}

sub get_compressed_binary {
    my $self = shift;

    my @tags = @{ $self->tags };

    # rebuild data
    my $raw = join("", $self->header, map { $_->get_binary } @tags);

    # calculate data length
    substr( $raw, 4, 4, pack( "V", length($raw) ) );

    my $compress_target_data = substr( $raw, 8 );
    my $not_compress_data    = substr( $raw, 0, 8);
    $raw = $not_compress_data . compress($compress_target_data);
    # update header signature
    substr( $raw, 0, 1, 'C' );

    $raw;
}

=pod

=head2 insert_movieclip

Insert movie clip which instance of SWF::Editor

  my $swf        = SWF::Editor->new(file => '/path/to/swf/movie');
  my $insert_swf = SWF::Editor->new(file => '/path/to/insert/swf/movie');
  my $matrix     = SWF::Editor::Variable::Matrix->new(translate_x => 100, translate_y => 200);

  #Insert $insert_swf into $swf at frame 2
  $swf->insert_movieclip(insert_swf => $insert_swf, frame_num => 2, name => 'hoge', matrix => $matrix);

=cut
sub insert_movieclip {
    args my $self,
         my $insert_swf => 'SWF::Editor',
         my $frame_num  => 'Int',
         my $matrix     => { isa => 'SWF::Editor::Variable::Matrix', optional => 1 },
         my $name       => { isa => 'Str', optional => 1 };

    $insert_swf = $insert_swf->clone;

    my @tags = @{$self->tags};

    #Parse max Character ID and max Depth at once.
    if ( !$self->{parsed_already} ) {
        for my $tag (@tags) {
            my $tag_name = get_tag_name($tag->type);
            if( $HAS_CID_TAGS{$tag_name} ) {
                my $cid = $tag->cid;
                $self->{max_cid} = $cid if !defined $self->{max_cid} || $self->{max_cid} < $cid;
            }
            if ( $tag_name eq 'PlaceObject2' ) {
                #depth
                my $depth = unpack("v", substr( $tag->data, 1, 2 ) );
                $self->{max_depth} = $depth if !defined $self->{max_depth} || $self->{max_depth} < $depth;
            }
        }
    }
    $self->{parsed_already} = 1;

    my $current_cid  = $self->{max_cid} + 1;
    my $current_depth  = $self->{max_depth} + 1;
    my %new_cid;
    for my $insert_tag (@{$insert_swf->tags}) {
        my $tag_name = get_tag_name($insert_tag->type);
        if ( $tag_name eq 'SetBackgroundColor' || $tag_name eq 'FileAttributes') {
            #Skip tag
            next;
        }
        my $data = $insert_tag->data;
        #Tags which has character id
        if ( $HAS_CID_TAGS{$tag_name} ) {
            my $old_cid = $insert_tag->cid;
            $insert_tag->cid($current_cid);
            $new_cid{$old_cid} = $current_cid;
            substr( $data, 0, 2, pack("v",$current_cid) );
            $current_cid++;
        }
        if ( $tag_name eq 'PlaceObject2' ) {
            #Get 7th bit ( has character id flag )
            my $has_character = ( ord( substr( $data, 0, 1 ) ) >> 1 ) & 1;
            my $depth = unpack("v", substr( $data, 1, 2 ) );
            if ( $depth <= $current_depth ) {
                substr( $data, 1, 2, pack("v",$current_depth) );
                $current_depth++;
            } elsif( $depth > $current_depth ) {
                $current_depth = $depth + 1;
            }
            if( $has_character ) {
                my $cid = unpack( "v", substr( $data, 3, 2 ) );
                #Replace character id
                if( defined $new_cid{$cid} ) {
                    my $replace_cid = $new_cid{$cid};
                    substr( $data, 3, 2, pack("v",$replace_cid) );
                }
            }
            #Replace binary data
            my $flg_bit = substr($data,0,1);
            my $flg_bits = [split //, unpack("B8",$flg_bit)];
            my $name_offset = 3;
            my $name_length = 0;
            if($flg_bits->[6]) {
                $name_offset += 2;
            }
            my $matrix_offset = $name_offset;
            if($flg_bits->[5]) {
                #Calculate matrix length
                my $iobit = SWF::Editor::Utils::IOBit->new( data => substr( $data, $name_offset ) );
                if ( $iobit->get_ui_bit ) {
                    my $length = $iobit->get_ui_bits(5);
                    $iobit->add_bit_offset($length * 2);
                }
                if ( $iobit->get_ui_bit ) {
                    my $length = $iobit->get_ui_bits(5);
                    $iobit->add_bit_offset($length * 2);
                }
                my $length = $iobit->get_ui_bits(5);
                $iobit->add_bit_offset($length * 2);
                $iobit->byte_align;
                $name_offset += $iobit->byte_offset;
            }
            if ( $matrix ) {
                #Replace matrix
                my $length = $name_offset - $matrix_offset;
                my $matrix_binary = $matrix->get_binary;
                $flg_bits->[5] = 1;
                $name_offset = $matrix_offset + length $matrix_binary;
                substr( $data, $matrix_offset, $length, $matrix_binary );
            }
            if($flg_bits->[4]) {
                #Calculate cxformwithalpha length
                my $iobit = SWF::Editor::Utils::IOBit->new( data => substr( $data, $name_offset ) );
                $iobit->add_bit_offset(2);
                my $length = $iobit->get_ui_bits(4);
                $iobit->add_bit_offset($length * 4);
                $iobit->byte_align;
                $name_offset += $iobit->byte_offset;
            }
            if($flg_bits->[3]) {
                $name_offset += 2;
            }
            if($flg_bits->[2]) {
                #Calculate name length
                my $iobit = SWF::Editor::Utils::IOBit->new( data => substr( $data, $name_offset ) );
                while(1) {
                    my $str_code = $iobit->get_ui8;
                    if( $str_code ) {
                        $name_length++;
                    } else {
                        $name_length++;
                        last;
                    }
                }
            }
            if ( $name ) {
                #Insert or replace name
                $flg_bits->[2] = 1;
                substr( $data, $name_offset, $name_length, $name.chr(0) );
            }
            #Update flag bit
            substr( $data, 0, 1, pack("B8", join('',@$flg_bits)) );
        }
        if( $tag_name eq 'DefineSprite' ) {
            my $mc_iobit = SWF::Editor::Utils::IOBit->new( data => $data );
            #Skip character id ( ui 16bit ) and frame count ( ui 16bit )
            $mc_iobit->add_byte_offset(4);
            while(1) {
                my $header = $mc_iobit->get_ui16_le;
                my $is_long_header = is_long_header($header);
                my $length = $is_long_header ? $mc_iobit->get_ui32_le : $header & 0x3F;
                my $offset = $mc_iobit->byte_offset;
                my $mc_data   = $mc_iobit->get_data($length);
                my $type   = $header >> 6;
                my $mc_tag_name = get_tag_name($type);
                if ( $mc_tag_name eq 'PlaceObject2' ) {
                    #Get flag bit
                    my $has_character = ( ord( substr( $mc_data, 0, 1 ) ) >> 1 ) & 1;
                    if( $has_character ) {
                        my $cid = unpack( "v", substr( $mc_data, 3, 2 ) );
                        #Replace character id
                        if( defined $new_cid{$cid} ) {
                            my $replace_cid = $new_cid{$cid};
                            substr( $mc_data, 3, 2, pack("v",$replace_cid) );
                            my $iobit_data = $mc_iobit->data;
                            substr( $iobit_data, $offset, length $mc_data, $mc_data );
                            $mc_iobit->data($iobit_data);
                        }
                    }
                }
                if ( $mc_tag_name eq 'End' ) {
                    last;
                }
            }
            $data = $mc_iobit->data;
        }
        if ( $tag_name eq 'ShowFrame' ) {
            last;
        }
        $insert_tag->data($data);
        $self->insert_tag_by_frame_no( $frame_num => $insert_tag );
    }
    $self->{max_cid} = $current_cid;
    $self->{max_depth} = $current_depth;
    return $self;
}

1;
__PACKAGE__->meta->make_immutable;
__END__
=head1 AUTHOR

Nishibayashi Takuji E<lt>takuji {at} senchan.jpE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

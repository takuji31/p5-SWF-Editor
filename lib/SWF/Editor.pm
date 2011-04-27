package SWF::Editor;
use strict;
use warnings;
use Mouse;
use Smart::Args;
use SWF::Parser;
use SWF::BinStream;

use SWF::Editor::Tag;
use SWF::Editor::Tag::FrameLabel;
use SWF::Editor::Utils::Tag;

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

=cut


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

__PACKAGE__->meta->make_immutable;
__END__
=head1 AUTHOR

Nishibayashi Takuji E<lt>takuji {at} senchan.jpE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

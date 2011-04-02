package SWF::Editor;
use strict;
use warnings;
use Mouse;
use Smart::Args;
use SWF::Parser;
use SWF::BinStream;

use SWF::Editor::Tag;

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


has file     => ( is => 'ro', isa => 'Str' );
has raw_data => ( is => 'ro', isa => 'Value', lazy_build => 1 );

has header => ( is => 'rw', isa => 'Str' );
has tags   => (
    is      => 'rw',
    isa     => 'ArrayRef[SWF::Editor::Tag]',
    default => sub { [] }
);

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

    my $tag_callback = sub {
        my ( $parser, $type, $length, $datastream ) = @_;

        my $header = $parser->{_tag}{header};
        my $data   = $datastream->get_string($length);

        push @{$self->tags}, SWF::Editor::Tag->new(
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

}

sub insert_tag {
    args_pos my $self,
             my $pos => { isa => 'Int' },
             my $tag => { isa => 'SWF::Editor::Tag' };

    splice @{$self->tags}, $pos,0,$tag;

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

sub clone {
    my $self = shift;
    my $class = ref($self);
    $class->meta->clone_object($self);
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

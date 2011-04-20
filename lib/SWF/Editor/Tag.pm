package SWF::Editor::Tag;

use Mouse;

use SWF::Editor::Utils::Header;

has data       => ( is => "rw" );
has header     => ( is => "rw" );
has type       => ( is => "rw", isa => 'Int', lazy_build => 1 );
has cid  => ( is => "rw", isa => 'Int', lazy_build => 1 );

sub get_binary {
    my $self = shift;

    if ( is_long_header($self->header) ) {
        pack("vVa*", $self->header, $self->length, $self->data);
    }
    else {
        my $header = $self->header;
        my $length = $self->length;
        my $type   = $header >> 6;
        $header = $type << 6 | $length;
        pack("va*", $header, $self->data);
    }
}

sub _build_cid {
    my $self = shift;

    unpack('v', substr($self->data, 0, 2));
}

sub _build_type {
    my $self = shift;

    return $self->header >> 6;
}

sub length {
    my $self = shift;
    return CORE::length $self->data;
}

sub clone {
    my $self = shift;
    my $class = ref($self);
    $class->meta->clone_object($self);
}

__PACKAGE__->meta->make_immutable;


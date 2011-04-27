package SWF::Editor::Tag::FrameLabel;

use Mouse;

extends qw/ SWF::Editor::Tag /;

use Smart::Args;

use SWF::Editor::Utils::Header;
use SWF::Editor::Utils::Tag;

has '+header' => ( default => create_long_header(get_tag_number('FrameLabel')) );
has name      => ( is => 'rw', isa => 'Str', lazy_build => 1 );

before get_binary => sub {
    my $self = shift;

    if ( $self->has_name ) {
        $self->data($self->name."\x00");
    }

};

sub BUILD {
    my $self = shift;

    if ( $self->has_name ) {
        $self->data($self->name . "\x00");
    } elsif ( !$self->has_data ) {
        confess("name is empty!");
    }
};

sub _build_name {
    my $self = shift;

    my $data = $self->data;
    #replace null bytes
    $data =~ s/\x00//g;
    return $data;
}

sub parse {
    args_pos my $class => 'ClassName',
             my $tag   => 'SWF::Editor::Tag';

    return unless compare_tag_number($tag->type, 'FrameLabel');

    return $class->new(
        data => $tag->data,
    );
}

__PACKAGE__->meta->make_immutable;


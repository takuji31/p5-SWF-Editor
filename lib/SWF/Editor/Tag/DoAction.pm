package  SWF::Editor::Tag::DoAction;
use Mouse;

extends qw/ SWF::Editor::Tag /;

use SWF::Editor::Utils::Header;
use SWF::Editor::Utils::Tag;

has '+header' => ( default => create_long_header(get_tag_number('DoAction')) );
# version default SWF7 ( FlashPlayer7 or FlashLite2.0 )
has 'version' => ( is => 'rw', isa => 'Int', default => 7 );
has 'action' => ( is => 'rw', isa => 'ArrayRef', default => sub { [] } );

sub add_action {
    my ($self, $action) = @_;
    return unless $action;
    push @{$self->action}, $action;
}

__PACKAGE__->meta->make_immutable;
__DATA__

=encoding utf8

=head1 NAME

SWF::Editor::Tag::DoAction

=head1 SYNOPSIS
  use SWF::Editor::Tag::DoAction;
=cut

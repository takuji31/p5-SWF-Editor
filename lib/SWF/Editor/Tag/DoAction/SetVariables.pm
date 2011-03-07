package  SWF::Editor::Tag::DoAction::SetVariables;
use Mouse;

extends qw/ SWF::Editor::Tag::DoAction /;
use Scalar::Util qw/looks_like_number/;
use Carp ();

has vars => ( is => "rw", isa => "HashRef", predicate => "has_vars", default => sub { +{} } );

our %ACTION_CODE = (
    Push        => "\x96",
    InitArray   => "\x42",
    SetVariable => "\x1d",
);
our %TYPE = (
    string     => "\x00",
    float      => "\x01",
    null       => "\x02",
    undefined  => "\x03",
    register   => "\x04",
    bool       => "\x05",
    double     => "\x06",
    integer    => "\x07",
    constant8  => "\x08",
    constant16 => "\x09",
);

our $NULL = "\x00";

has vars => ( is => "rw", isa => "HashRef", predicate => "has_vars", required => 1 );

sub BUILD {
    my $self = shift;
    $self->compile;
}

sub add {
    my ( $self, $key, $value ) = @_;
    Carp::croak("Key or value is not defined") unless defined $key && defined $value;
    $self->vars->{$key} = $value;
}

sub compile {
    my $self = shift;
    my $vars = $self->vars;

    my @vars    = ();
    my @actions = ();
    while ( my ($key, $value) = each %{ $vars } ) {
        #encode key
        push @vars, $self->compile_value($key), $self->compile_value($value);
        push @actions, $ACTION_CODE{SetVariable};
    }
    my $compiled_vars = join '', @vars, @actions;
    $self->data($compiled_vars);
}

sub compile_value {
    my ( $self, $value ) = @_;

    if( ref($value) eq 'ARRAY' ) {
        return $self->compile_array($value);
    }
    elsif ( looks_like_number($value) ) {
        #integer
        return $self->compile_integer($value);
    }
    elsif ( !ref($value) ) {
        #string
        utf8::encode($value) if utf8::is_utf8($value);
        return $self->compile_string($value);
    }
    else {
        #other
        Carp::croak("Value must be a string, integer or array ref!");
    }
}

sub compile_array {
    my ( $self, $values ) = @_;
    my @compiled_values = ( $self->compile_value( scalar @$values ), $ACTION_CODE{InitArray} );
    for my $value ( @$values ) {
        unshift @compiled_values, $self->compile_value($value);
    }
    return join '', @compiled_values;
}

sub compile_string {
    my ( $self, $value ) = @_;
    return join '', $ACTION_CODE{Push}, pack( 'v', length($value) + 2 ), $TYPE{string}, $value, $NULL;
}

sub compile_integer {
    my ( $self, $value ) = @_;
    return join '', $ACTION_CODE{Push}, pack( 'v', 5 ), $TYPE{integer}, pack( 'V', $value );
}

__PACKAGE__->meta->make_immutable;
__DATA__

=encoding utf8

=head1 NAME

SWF::Editor::Tag::DoAction::SetVariables - DoAction tag for set variables

=head1 SYNOPSIS
  use SWF::Editor::Tag::DoAction::SetVariables;

  my $tag = SWF::Editor::Tag::DoAction::SetVariables->new;
  #add string
  $tag->add( hoge => 'huga' );
  #add integer
  $tag->add( foo  => 1 );
  #add array
  $tag->add( bar  => [qw/ aaa bbb /] );
  $tag->get_binary;

  # or

  my $tag2 = SWF::Editor::Tag::DoAction::SetVariables->new(
      vars => {
          hoge => 'fuga',
          foo  => 1,
          bar  => [qw/ aaa bbb /],
      },
  );
  $tag2->get_binary;

=cut

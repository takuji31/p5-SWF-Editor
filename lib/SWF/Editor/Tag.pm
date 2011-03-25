package SWF::Editor::Tag;

use Mouse;

use SWF::Editor::Utils::Header;

has data       => ( is => "rw" );
has header     => ( is => "rw" );
has type       => ( is => "rw" );
has object_id  => ( is => "rw", isa => 'Int', lazy_build => 1 );
has binary     => ( is => "rw", lazy_build => 1 );

sub get_binary {
    my $self = shift;

    if ( is_long_header($self->header) ) {
        pack("vVa*", $self->header, $self->length, $self->data);
    }
    else {
        pack("va*",  $self->header,                $self->data);
    }
}

sub _build_object_id {
    my $self = shift;

    unpack('v', substr($self->data, 0, 2));
}

sub length {
    my $self = shift;
    return length $self->data;
}

our $TAG_NUMBER = {
    End                          => 0,
    ShowFrame                    => 1,
    DefineShape                  => 2,
    FreeCharacter                => 3,
    PlaceObject                  => 4,
    RemoveObject                 => 5,
    DefineBits                   => 6,
    DefineButton                 => 7,
    JPEGTables                   => 8,
    SetBackgroundColor           => 9,
    DefineFont                   => 10,
    DefineText                   => 11,
    DoAction                     => 12,
    DefineFontInfo               => 13,
    DefineSound                  => 14,
    StartSound                   => 15,
    StopSound                    => 16,
    DefineButtonSound            => 17,
    SoundStreamHead              => 18,
    SoundStreamBlock             => 19,
    DefineBitsLossless           => 20,
    DefineBitsJPEG2              => 21,
    DefineShape2                 => 22,
    DefineButtonCxform           => 23,
    Protect                      => 24,
    PathsArePostscript           => 25,
    PlaceObject2                 => 26,
    RemoveObject2                => 28,
    SyncFrame                    => 29,
    FreeAll                      => 31,
    DefineShape3                 => 32,
    DefineText2                  => 33,
    DefineButton2                => 34,
    DefineBitsJPEG3              => 35,
    DefineBitsLossless2          => 36,
    DefineEditText               => 37,
    DefineVideo                  => 38,
    DefineSprite                 => 39,
    NameCharacter                => 40,
    ProductInfo                  => 41,
    DefineTextFormat             => 42,
    FrameLabel                   => 43,
    SoundStreamHead2             => 45,
    DefineMorphShape             => 46,
    GenerateFrame                => 47,
    DefineFont2                  => 48,
    GeneratorCommand             => 49,
    DefineCommandObject          => 50,
    CharacterSet                 => 51,
    ExternalFont                 => 52,
    ExportAssets                 => 56,
    ImportAssets                 => 57,
    EnableDebugger               => 58,
    DoInitAction                 => 59,
    DefineVideoStream            => 60,
    VideoFrame                   => 61,
    DefineFontInfo2              => 62,
    DebugID                      => 63,
    EnableDebugger2              => 64,
    ScriptLimits                 => 65,
    SetTabIndex                  => 66,
    FileAttributes               => 69,
    PlaceObject3                 => 70,
    ImportAssets2                => 71,
    DefineFontAlignZones         => 73,
    CSMTextSettings              => 74,
    DefineFont3                  => 75,
    SymbolClass                  => 76,
    Metadata                     => 77,
    DefineScalingGrid            => 78,
    DoABC                        => 82,
    DefineShape4                 => 83,
    DefineMorphShape2            => 84,
    DefineSceneAndFrameLabelData => 86,
    DefineBinaryData             => 87,
    DefineFontName               => 88,
    StartSound2                  => 89,
    DefineBitsJPEG4              => 90,
    DefineFont4                  => 91,
};

sub tag_number {
    my ( $self, $tag_name ) = @_;
    confess("Tag name does not passed!") unless $tag_name;
    confess("Tag $tag_name does not exists!") unless $TAG_NUMBER->{$tag_name};
    $TAG_NUMBER->{$tag_name};
}

__PACKAGE__->meta->make_immutable;


package  SWF::Editor::Utils::Tag;
use strict;
use warnings;

use SWF::Editor::Tag;
use Exporter::Lite;

our @EXPORT = qw/
    compare_tag_number
    get_tag_name
    get_tag_number
/;

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

sub compare_tag_number {
    my ( $tag_number, $tag_name ) = @_;
    my $correct_tag_number = get_tag_number($tag_name);
    return $correct_tag_number == $tag_number;
}

sub get_tag_name {
    my $tag_number = shift;
    confess("Tag name does not passed!") unless defined $tag_number;
    return {reverse %$TAG_NUMBER}->{$tag_number};
}

sub get_tag_number {
    my $tag_name = shift;
    confess("Tag name does not passed!") unless defined $tag_name;
    confess("Tag $tag_name does not exists!") unless defined $TAG_NUMBER->{$tag_name};
    return $TAG_NUMBER->{$tag_name};
}


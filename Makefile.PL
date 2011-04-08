use inc::Module::Install;
name 'SWF-Editor';
all_from 'lib/SWF/Editor.pm';
githubmeta;

build_requires 'Test::LoadAllModules';
build_requires 'Test::More';

# requires '';
requires 'Carp';
requires 'Compress::Zlib';
requires 'Mouse';
requires 'Scalar::Util';
requires 'Smart::Args';
requires 'SWF::Parser';
requires 'SWF::BinStream';
requires 'Exporter::Lite';

tests 't/*.t';
author_tests 'xt';

auto_set_repository;
auto_include;
WriteAll;

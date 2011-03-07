use inc::Module::Install;
name 'SWF-Editor';
all_from 'lib/SWF/Editor.pm';
githubmeta;

# requires '';
requires 'Mouse';
requires 'Carp';
requires 'Scalar::Util';
requires 'Smart::Args';
requires 'SWF::Parser';
requires 'SWF::BinStream';

tests 't/*.t';
author_tests 'xt';

build_requires 'Test::More';
auto_set_repository;
auto_include;
WriteAll;

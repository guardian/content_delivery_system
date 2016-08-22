#!/usr/bin/env perl

$ENV{'cf_media_file'}="/path/to/random_long_file_name_with_sections_xxxx.mov";
$ENV{'filename-skip-portions'}=1;
$ENV{'filename-portion-delimiter'}='_';
#$ENV{'invert'}='true';
$ENV{'debug'}='true';
$ENV{'from-end'}='true';

system('./scripts/remove_filename_portions.pl');

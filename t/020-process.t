#!perl6

use v6;
use lib 'lib';
use Test;

use Audio::Convert::Samplerate;
use Audio::Sndfile;

my $test-data = $*CWD.child('t/data');

my $test-file-in    = $test-data.child('1sec-chirp-22050.wav');
my $test-file-out   = $test-data.child("test-out-{ $*PID }.wav");

my Audio::Sndfile $in-obj;

lives-ok { $in-obj = Audio::Sndfile.new(filename => $test-file-in, :r) }, "open test file for reading";

my Audio::Convert::Samplerate $conv-obj;

lives-ok { $conv-obj = Audio::Convert::Samplerate.new(channels => $in-obj.channels) }, "create a new Audio::Convert::Samplerate";

my $bufsize = 1024;

loop {
    my ($in-frames, $num-frames) = $in-obj.read-float($bufsize, :raw).list;
    say $num-frames;
    my $buf;
    $buf = $conv-obj.process($in-frames, $num-frames, 2);
    last if $num-frames != $bufsize;
}



done;
# vim: expandtab shiftwidth=4 ft=perl6

use v6;

class Audio::Convert::Samplerate:ver<v0.0.1>:auth<github:jonathanstowe> {
    use NativeCall;
    use NativeHelpers::Array;

    subset RawProcess of Array where  ($_.elems == 2 ) && ($_[0] ~~ CArray) && ($_[1] ~~ Int);

    enum Type <Best Medium Fastest OrderHold Linear>;

    class X::ConvertError is Exception {
        has Int $.error-code = 0;

        sub src_strerror(int32 $error) returns Str is native('libsamplerate') { * }

        method message() returns Str {
            src_strerror($!error-code);
        }
    }

    class X::InvalidRatio is Exception {
        has Num $.ratio is required;

        method message() returns Str {
            "The convertion ratio { $!ratio } is not valid";
        }
    }

    class Data is repr('CStruct') {
        has CArray[num32] $.data-in;
        has CArray[num32] $.data-out;
        has int64 $.input-frames;
        has int64 $.output-frames;
        has int64 $.input-frames-used;
        has int64 $.output-frames-gen;
        has int32 $.end-of-input;
        has num64 $.src-ratio;

        submethod BUILD(CArray[num32] :$data-in!, Int :$input-frames!, Num() :$src-ratio!, Int :$channels = 2, Bool :$last = False) {
            $!data-in := $data-in;
            $!input-frames = $input-frames;
            $!src-ratio = $src-ratio;
            my CArray[num32] $data-out := CArray[num32].new;
            $!output-frames = ($input-frames * $src-ratio).Int + 10;
            $data-out[$!output-frames * $channels] = 0;
            $!data-out := $data-out;
            $!input-frames-used = 0;
            $!output-frames-gen = 0;
            $!end-of-input = $last ?? 1 !! 0;
        }
    }

    class State is repr('CPointer') {

        sub src_new(int32 $converter-type, int32 $channels, int32 $error) returns State is native('libsamplerate') { * }

        method new(Type $type, Int $channels) returns State {
            my Int $error = 0;
            my $state = src_new($type.Int, $channels, $error);

            if not $state.defined {
                X::ConvertError.new(error-code => $error).throw;
            }

            $state;
        }

        sub src_process(State $st, Data $d is rw) returns int32 is native('libsamplerate') { * }

        multi method process(Data $data is rw) returns Data {
            my $rc = src_process(self, $data);

            if $rc != 0 {
                X::ConvertError.new(error-code => $rc).throw;
            }
            $data;
        }

        # put this in here as it simplifies matters
        sub src_is_valid_ratio (num64 $ratio) returns int32 is native('libsamplerate') { * }

        method is-valid-ratio(Num $ratio) returns Bool {
            if src_is_valid_ratio($ratio) {
                True;
            }
            else {
                False;
            }
        }

        sub src_set_ratio(State $state, num64 $new_ratio) returns int32 is native('libsamplerate') { * }

        method set-ratio(Num $new-ratio) {
            my $rc = src_set_ratio(self, $new-ratio);

            if $rc != 0 {
                X::ConvertError.new(error-code => $rc).throw;
            }
        }

        sub src_reset(State) returns int32 is native('libsamplerate') { * }

        method reset() {
            my $rc = src_reset(self);

            if $rc != 0 {
                X::ConvertError.new(error-code => $rc).throw;
            }
        }

        sub src_delete(State) is native('libsamplerate') { * }

        method DESTROY() {
            src_delete(self);
        }

    }


    has Type  $!type;
    has Int   $!channels;
    has State $!state handles <is-valid-ratio>;

    submethod BUILD(Type :$!type = Medium, Int :$!channels = 2) {
        $!state = State.new($!type, $!channels);
    }

    sub src_get_version() returns Str is native('libsamplerate') { * }

    method samplerate-version() returns Version {
        my $v = src_get_version();
        Version.new($v);
    }

    multi method process(CArray[num32] $data-in, Int $input-frames, Num() $src-ratio, Bool $last = False) returns RawProcess {

        if not self.is-valid-ratio($src-ratio) {
            X::InvalidRatio.new.throw;
        }


        my Data $data = Data.new(:$data-in, :$input-frames, :$last, :$src-ratio);

        $data = $!state.process($data);
        refresh($data);

        [ $data.data-out, $data.output-frames-gen ];
    }

    multi method process(CArray[int16] $data-in, Int $input-frames, Num() $src-ratio, Bool $last = False) returns RawProcess {
        my CArray[num32] $new-data = CArray[num32].new;
        my Int $total-frames = ($input-frames * $!channels).Int;
        $new-data[$total-frames] = 0;
        src_short_to_float_array($data-in, $new-data, $total-frames);
        (my $float-out, my $frames-out ) = self.process($new-data, $input-frames, $src-ratio, $last).list;
        my CArray[int16] $int-out = CArray[int16].new;
        my Int $total-out = ($frames-out * $!channels).Int;
        $int-out[$total-out] = 0;
        src_float_to_short_array($float-out, $int-out, $total-out);
        [ $int-out, $frames-out ]
    }

    multi method process(CArray[int32] $data-in, Int $input-frames, Num() $src-ratio, Bool $last = False) returns RawProcess {
        my CArray[num32] $new-data = CArray[num32].new;
        my Int $total-frames = ($input-frames * $!channels).Int;
        $new-data[$total-frames] = 0;
        src_int_to_float_array($data-in, $new-data, $total-frames);
        (my $float-out, my $frames-out ) = self.process($new-data, $input-frames, $src-ratio, $last).list;
        my CArray[int32] $int-out = CArray[int32].new;
        my Int $total-out = ($frames-out * $!channels).Int;
        $int-out[$total-out] = 0;
        src_float_to_int_array($float-out, $int-out, $total-out);
        [ $int-out, $frames-out ]
    }

    sub src_short_to_float_array(CArray[int16] $in, CArray[num32] $out, int32 $len) is native('libsamplerate') { * }
    sub src_float_to_short_array(CArray[num32] $in, CArray[int16] $out, int32 $len) is native('libsamplerate') { * }

    sub src_int_to_float_array(CArray[int32] $in, CArray[num32] $out, int32 $len) is native('libsamplerate') { * }
    sub src_float_to_int_array(CArray[num32] $in, CArray[int32] $out, int32 $len) is native('libsamplerate') { * }

}

# vim: expandtab shiftwidth=4 ft=perl6

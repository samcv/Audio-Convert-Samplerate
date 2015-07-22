use v6;

class Audio::Convert::Samplerate:ver<v0.0.1>:auth<github:jonathanstowe> {
    use NativeCall;

    enum Type <Best Medium Fastest OrderHold Linear>;

    class X::ConvertError is Exception {
        has Int $.error-code = 0;

        sub src_strerror(int32 $error) returns Str is native('libsamplerate') { * }

        method message() returns Str {
            src_strerror($!error-code);
        }
    }

    class Data is repr('CStruct') {
        has CArray[num32] $.data-in is rw;
        has CArray[num32] $.data-out is rw;
        has int64 $.input-frames is rw;
        has int64 $.output-frames is rw;
        has int64 $.input-frames-used is rw;
        has int64 $.output-frames-gen is rw;
        has int32 $.end-of-input is rw;
        has num64 $.src-ratio is rw;
    }

    class State is repr('CPointer') {

        sub src_new(int32 $converter-type, int32 $channels, int32 $error) returns State is native('libsamplerate') { * }

        method new(Type $type, Int $channels) returns State {
            my Int $error = 0;
            say $type.WHAT, $channels.WHAT;
            my $state = src_new($type.Int, $channels, $error);

            if not $state.defined {
                X::ConvertError.new(error-code => $error).throw;
            }

            $state;
        }

        sub src_process(State, Data) returns int32 is native('libsamplerate') { * }

        multi method process(Data $data is rw) {
            my $rc = src_process(self, $data);

            if $rc != 0 {
                X::ConvertError.new(error-code => $rc).throw;
            }
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


    has State $!state;

    submethod BUILD(Type :$type = Medium, Int :$channels = 2) {
        $!state = State.new($type, $channels);
    }

    sub src_get_version() returns Str is native('libsamplerate') { * }

    method samplerate-version() returns Version {
        my $v = src_get_version();
        Version.new($v);
    }
}

# vim: expandtab shiftwidth=4 ft=perl6

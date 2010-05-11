package App::GitHub::updatedescription::GitHubCfg;

use strict;
use warnings;

use Carp;
use IPC::Open3 qw/ open3 /;
use Symbol qw/ gensym /;

sub decrypt {
    my $self = shift;
    my $input = shift;

    my ( $in, $out, $error ) = ( gensym, gensym, gensym );
    my $command = 'gpg -d -q --no-tty --command-fd 0 --status-fd 1';
    $command = 'gpg -d -q --no-tty --command-fd 0';
    my $process = open3( $in, $out, $error, "$command" );
    print $in "$input\n";
    close $in;
    my $output = join '', <$out>;
    my $_error = join '', <$error>;
    return ( $output, $_error );
}

sub read {
    my $self = shift;
    my $file = shift || "$ENV{HOME}/.github";
    croak "Missing .github ($file)" unless -f $file;
    croak "Cannot read .github ($file)" unless -r $file;

    open my $handle, $file or croak $!;
    my $content = join '', <$handle>;
    close $handle or warn $!;

    if ( $content =~ m/----BEGIN PGP MESSAGE----/ ) {
        my ( $_content, $error ) = $self->decrypt( $content );
        if ( $error ) {
            carp "Error during decryption of content:\n$content";
            croak "Error during decryption of $file:\n$error";
        }
        $content = $_content;
    }
    
    return $content;
}

sub parse {
    my $self = shift;
    my $content = shift;
    croak "Missing content" unless $content;
    croak "Invalid content:\n$content"
        unless my @content = $content =~ m/^[\t ]*([^=]+?)[\t ]*=[\t ]*(.*?)$/msg;
    my %content = @content;
    my ( $username, $token ) = @content{qw/ username token /};
    defined $content{$_} && length $content{$_} or croak "Missing $_" for qw/ username token /;
    return %content;
}

sub slurp {
    my $self = shift;
    return $self->parse( $self->read );
}

1;

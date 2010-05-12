package App::GitHub::update;
# ABSTRACT: Update a github repository (description, etc.) from the command-line

=head1 SYNOPSIS

    # Update the description of github:alice/example
    github-update --login alice --token 42fe60... --repository example --description "Xyzzy"

    # Pulling login and token from $HOME/.github
    github-update --repository example --description "Xyzzy"

=head1 DESCRIPTION

A simple tool for setting the description and homepage of a github repository

=head1 GitHub identity format ($HOME/.github or $HOME/.github-identity)

    login <login>
    token <token>

Optionally GnuPG encrypted

=cut

use strict;
use warnings;

use Config::Identity::GitHub;
use LWP::UserAgent;
use Getopt::Long qw/ GetOptions /;
my $agent = LWP::UserAgent->new;

sub update {
    my $self = shift;
    my %given = @_;
    my ( $login, $token, $repository, $description, $homepage );

    ( $repository, $description, $homepage ) = @given{qw/ repository description homepage /};
    defined $_ && length $_ or die "Missing repository\n" for $repository;

    ( $login, $token ) = @given{qw/ login token /};
    unless( defined $token && length $token ) {
        my %identity = Config::Identity::GitHub->load;
        ( $login, $token ) = @identity{qw/ login token /};
    }

    my @arguments;
    push @arguments, 'values[description]' => $description if defined $description;
    push @arguments, 'values[homepage]' => $homepage if defined $homepage;

    my $uri = "https://github.com/api/v2/json/repos/show/$login/$repository";
    my $response = $agent->post( $uri,
        [ login => $login, token => $token, @arguments ] );

    unless ( $response->is_success ) {
        carp $response->status_line;
        croak $response->decoded_content
    }

    return $response;
}

sub usage (;$) {
    my $error = shift;
    do { chomp $error; warn $error, "\n" } if $error;
    warn <<_END_;

Usage: github-update [opt] <description>

    --login ...         Your github login

    --token ...         The github token associated with the given login

    --repository ...    The repository to update

    --dzpl              Guess repository and description from Dist::Dzpl
                        configuration (name and abstract, respectively)

    --help, -h, -?      This help

    <description>       The new description for the repository

_END_

    exit -1 if $error;
}

sub guess_dzpl {
    my $self = shift;
    my %guess;

    eval {
        # Oh god this is hacky
        package App::GitHub::update::Sandbox;
        local @ARGV;
        do './dzpl';
        my $dzpl = $Dzpl::dzpl;
        $dzpl = $Dzpl::dzpl;
        $dzpl->zilla->_setup_default_plugins;
        $_->gather_files for ( @{ $dzpl->zilla->plugins_with(-FileGatherer) } );
        $guess{repository} = $dzpl->zilla->name;
        $guess{description} = $dzpl->zilla->abstract;
    };
    die $@ if $@;

    return %guess;
}

sub run {
    my $self = shift;
    my @arguments = @_;

    my ( $login, $token, $repository, $dzpl, $help );
    my ( $homepage, $description );
    {
        local @ARGV = @arguments;
        GetOptions(
            'help|h|?' => \$help,
            'login=s' => \$login,
            'token=s' => \$token,
            'repository=s' => \$repository,
            'dzpl' => \$dzpl,

            'description=s' => \$description,
            'homepage=s' => \$homepage,
        );
    }

    if ($help) {
        usage;
        exit 0;
    }

    if ( $dzpl ) {
        my %guess = $self->guess_dzpl;
        $repository ||= $guess{repository};
        $description ||= $guess{description};
    }
    
    eval {
        my $response = $self->update(
            login => $login, token => $token, repository => $repository,
            description => $description, homepage => $homepage,
        );

        print $response->as_string, "\n";
    };
    if ($@) {
        usage <<_END_;
github-update: $@
_END_
    }
}

1;

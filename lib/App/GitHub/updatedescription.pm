package App::GitHub::updatedescription;
# ABSTRACT: Update a github repository description from the command-line

use strict;
use warnings;

use Carp;
use App::GitHub::updatedescription::GitHubCfg;
use LWP::UserAgent;
use Getopt::Long qw/ GetOptions /;
my $agent = LWP::UserAgent->new;

sub update {
    my $self = shift;
    my %given = @_;
    my ( $username, $token, $repository, $description );

    ( $repository, $description ) = @given{qw/ repository description /};
    defined $_ && length $_ or croak "Missing repository" for $repository;
    defined $_ && length $_ or croak "Missing description" for $description;

    ( $username, $token ) = @given{qw/ username token /};
    unless( defined $token && length $token ) {
        my %cfg = App::GitHub::updatedescription::GitHubCfg->slurp;
        ( $username, $token ) = @cfg{qw/ username token /};
    }

    my $uri = "https://github.com/api/v2/json/repos/show/$username/$repository";
    my $response = $agent->post( $uri,
        [ login => $username, token => $token, 'values[description]' => $description ] );

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

Usage: github-updatedescription [opt] <description>

    --username ...      Your github username

    --token ...         The github token associated with the given username

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
        package App::GitHub::updatedescription::_garbage;
        local @ARGV;
        do './dzpl';
        my $dzpl = $Dzpl::dzpl;
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

    my ( $username, $token, $repository, $description, $dzpl, $help );
    {
        local @ARGV = @arguments;
        GetOptions(
            'help|h|?' => \$help,
            'username=s' => \$username,
            'token=s' => \$token,
            'repository=s' => \$repository,
            'dzpl' => \$dzpl,
        );
        $description = join ' ', @ARGV;
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

    usage <<_END_ unless $description;
$0: You need to specify a description
_END_

    my $response = $self->update(
        username => $username, token => $token,
        repository => $repository, description => $description );

    print $response->as_string, "\n";
}

1;

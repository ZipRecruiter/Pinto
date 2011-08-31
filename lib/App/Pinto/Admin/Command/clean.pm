package App::Pinto::Admin::Command::clean;

# ABSTRACT: remove all distributions that are not in the index

use strict;
use warnings;

use IO::Interactive;

#-----------------------------------------------------------------------------

use base 'App::Pinto::Admin::Command';

#------------------------------------------------------------------------------

# VERSION

#------------------------------------------------------------------------------

sub opt_spec {
    my ($self, $app) = @_;

    # TODO: add option to prompt before cleaning each dist

    return ( $self->SUPER::opt_spec(),

        [ 'message=s' => 'Prepend a message to the VCS log' ],
        [ 'noinit'    => 'Do not pull/update from VCS' ],
        [ 'tag=s'     => 'Specify a VCS tag name' ]
    );
}

#------------------------------------------------------------------------------

sub validate_args {
    my ($self, $opts, $args) = @_;

    $self->SUPER::validate_args($opts, $args);

    $self->usage_error('Arguments are not allowed') if @{ $args };

    return 1;
}

#------------------------------------------------------------------------------

sub execute {
    my ($self, $opts, $args) = @_;

    $self->pinto->new_action_batch( %{$opts} );
    $self->pinto->add_action('Clean', %{$opts});

    $self->prompt_for_confirmation() if IO::Interactive::is_interactive();

    my $result = $self->pinto->run_actions();
    return $result->is_success() ? 0 : 1;
}

#------------------------------------------------------------------------------

sub prompt_for_confirmation {
    my ($self) = @_;

    print <<'END_MESSAGE';
Cleaning the repository will remove all distributions that is not in
the current index.  As a result, it will become impossible to install
older versions of distributions from your repository.

Once cleaned, the only way to get those distributions back in your
repository is to roll back your VCS (if applicable), or manually fetch
them from CPAN (if they can be found) and add them to your repository.

END_MESSAGE

    my $answer = '';

    until ($answer =~ m/[yn]/ix) {
        print "Are you sure you want to proceed? [Y/N]: ";
        chomp( $answer = uc <STDIN> );
    }

    exit 0 if $answer eq 'N';
    return 1;
}

#------------------------------------------------------------------------------

1;

__END__

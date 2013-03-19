# ABSTRACT: Records every Action

package Pinto::Logger;

use Moose;
use MooseX::StrictConstructor;
use MooseX::Types::Moose qw(Str);
use MooseX::MarkAsMethods (autoclean => 1);

use JSON;
use DateTime;

use Pinto::Util qw(itis);
use Pinto::Types qw(Dir File);
use Pinto::Exception qw(throw);

#-----------------------------------------------------------------------------

# VERSION

#-----------------------------------------------------------------------------

with qw(Pinto::Role::Configurable);

#-----------------------------------------------------------------------------

has log_file => (
    is      => 'ro',
    isa     => File,
    default => sub { $_[0]->config->log_file },
    coerce  => 1,
);

#-----------------------------------------------------------------------------

sub log_action {

}

#-----------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

#-----------------------------------------------------------------------------

1;

__END__


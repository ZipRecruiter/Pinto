# ABSTRACT: Associates packages with a stack

package Pinto::Registry;

use Moose;
use MooseX::Types::Moose qw(HashRef Bool);

use Pinto::Types qw(File);
use Pinto::Exception qw(throw);
use Pinto::RegistryEntry;

use PerlIO::gzip;

use namespace::autoclean;

#------------------------------------------------------------------------

# VERSION

#------------------------------------------------------------------------

has file => (
    is         => 'ro',
    isa        => File,
    required   => 1,
);


has entries_by_distribution => (
    is        => 'ro',
    isa       => HashRef,
    default   => sub { {} },
);


has entries_by_package => (
    is        => 'ro',
    isa       => HashRef,
    default   => sub { {} },
);


has has_changed => (
    is          => 'ro',
    isa         => Bool,
    writer      => '_set_has_changed',
    default     => 0,
    init_arg    => undef,
);

#------------------------------------------------------------------------------

with qw(Pinto::Role::Loggable);

#------------------------------------------------------------------------------

sub BUILD {
    my ($self) = @_;

    my $file = $self->file;
    return $self if not -e $file;

    open my $fh, '<', $file or throw "Failed to open index file $file: $!";

    while (<$fh>) {
      my $entry = Pinto::RegistryEntry->new($_);
      $self->add(entry => $entry);
    }

    close $fh;

    # Additions do not count as changes during
    # construction, so reset the has_changed flag.
    $self->_set_has_changed(0);

    return $self;
}

#------------------------------------------------------------------------

sub add {
  my ($self, %args) = @_;

  my $entry = $args{entry};
  my $pkg   = $entry->package;
  my $dist  = $entry->distribution;

  $self->entries_by_distribution->{$dist}->{$pkg} = $entry;
  $self->entries_by_package->{$pkg} = $entry;

  $self->_set_has_changed(1);

  $self;

}

#------------------------------------------------------------------------

sub delete {
  my ($self, %args) = @_;

  my $entry = $args{entry};
  my $pkg   = $entry->package;
  my $dist  = $entry->distribution;

  delete $self->entries_by_package->{$pkg};
  delete $self->entries_by_distribution->{$dist}->{$pkg};

  my %remaining_pkgs = %{ $self->entries_by_distribution->{$dist} };
  delete $self->entries_by_distribution->{$dist} if not %remaining_pkgs;

  $self->_set_has_changed(1);

  return $self;
}

#------------------------------------------------------------------------

sub entries {
    my ($self) = @_;

    my @keys = sort keys %{ $self->entries_by_package };

    return [ @{$self->entries_by_package}{@keys} ]; # Slicing!
}

#------------------------------------------------------------------------

sub lookup {
  my ($self, %args) = @_;

  if (my $pkg = $args{package}) {
    return $self->entries_by_package->{$pkg};
  }
  elsif (my $dist = $args{distribution}) {
    return $self->entries_by_distribution->{$dist};
  }
  else {
    throw "Don't know what to do"
  }
}

#------------------------------------------------------------------------

sub register {
  my ($self, %args) = @_;

  return $self->register_distribution(%args) if $args{distribution};
  return $self->register_package(%args)      if $args{package};

  throw "Don't know what to do with %args";

}

#------------------------------------------------------------------------
sub register_distribution {
  my ($self, %args) = @_;

  my $dist  = $args{distribution};
  my $force = $args{force};
  my $pin   = $args{pin};

  my $errors = 0;
    for my $pkg ($dist->packages) {

      my $pkg_name  = $pkg->name;
      my $incumbent = $self->lookup(package => $pkg_name);

      if (not defined $incumbent) {
          $self->debug(sub {"Registering $pkg on stack"} );
          $self->register_package(package => $pkg, pin => $pin);
          next;
      }


      if ($pkg == $incumbent) {
        $self->debug( sub {"Package $pkg is already on stack"} );
        $incumbent->pin && $self->_set_has_changed(1) if $pin and not $incumbent->is_pinned;
        next;
      }


      if ($incumbent->is_pinned) {
        $self->error("Cannot add $pkg to stack because $pkg_name is pinned to $incumbent");
        $errors++;
        next;
      }

      my ($log_as, $direction) = ($pkg < $incumbent) ? ('warning', 'Downgrading')
                                                     : ('notice',  'Upgrading');

      $self->delete(entry => $incumbent);
      $self->$log_as("$direction package $incumbent to $pkg");
      $self->register_package(package => $pkg, pin => $pin);
    }

    throw "Unable to register distribution $dist on stack" if $errors;

    return $self;

}

#------------------------------------------------------------------------

sub register_package {
  my ($self, %args) = @_;

  my $pkg = $args{package};
  my $pin = $args{pin} || 0;

  my %struct = $pkg->as_struct;
  my $entry = Pinto::RegistryEntry->new(%struct, is_pinned => $pin);

  $self->add(entry => $entry);

  return $entry;
}

#------------------------------------------------------------------------

sub unregister_distributon {
  my ($self, %args) = @_;

  my $dist  = $args{distribution};
  my $force = $args{force};

  # for my $pkg ($dist->packages) {
  #   my $pkg_name = $pkg->name;
  # 
  # }
  # my $entry = delete $self->entries_by_distribution->{$dist} or throw "No dist";
  # delete $self->entries_by_package->{$_} for {map $_->package} @{ $entry };

  return $self;
}

#------------------------------------------------------------------------

sub unregister_package {
  my ($self, %args) = @_;

  my $pkg   = $args{package};
  my $force = $args{force};

  # my $entry = delete $self->entries_by_distribution->{$dist} or throw "No dist";
  # delete $self->entries_by_package->{$_} for {map $_->package} @{ $entry };

  return $self;
}


#------------------------------------------------------------------------

sub pin {
    my ($self, %args) = @_;

    my $dist    = $args{distribution};
    my $entries = $self->lookup(%args);

    throw "Distribution $dist is not registered on this stack" if not defined $entries;

    for my $entry (values %{ $entries }) {
      next if $entry->is_pinned;
      $self->_set_has_changed(1);
      $entry->pin;
    }

    return $self
}

#------------------------------------------------------------------------

sub unpin {
    my ($self, %args) = @_;

    my $dist = $args{distribution};
    my $entries = $self->entries_by_distribution->{$dist};

    throw "Distribution $dist is not registered on this stack" if not defined $entries;

    for my $entry (values %{ $entries }) {
      next if not $entry->is_pinned;
      $self->_set_has_changed(1);
      $entry->unpin;
    }

    return $self
}

#------------------------------------------------------------------------

sub entry_count {
  my ($self) = @_;

  return scalar keys %{ $self->entries_by_package };
}

#------------------------------------------------------------------------

sub write {
  my ($self) = @_;

  my $format = "%-24p %12v %-48h %i %t\n";

  my $fh = $self->file->openw;
  print { $fh } $_->to_string($format) for @{ $self->entries };
  close $fh;

  return $self;
}

#------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

#------------------------------------------------------------------------
1;

package Test::Builder2::TestState;

use Test::Builder2::Mouse;
use Test::Builder2::Types;

with 'Test::Builder2::Singleton',
     'Test::Builder2::CanLoad';

has _coordinators =>
  is            => 'rw',
  isa           => "ArrayRef[Object]",
  # The first one will be added at create() time because triggers don't work on default
  # and we need to delegate when a coordinator is added.
  default       => sub { [] },
  documentation => "A stack of EventCoordinators";

has _coordinator_constructor_args =>
  is            => 'rw',
  isa           => 'HashRef',
  default       => sub { {} },
  documentation => <<END;
Arguments passed to the TestState constructor which are passed on to the coordinator.
END

has coordinator_class =>
  is            => 'rw',
  isa           => 'ClassName',
  default       => 'Test::Builder2::EventCoordinator',
  documentation => <<END;
The class to make event coordinators from.
END


sub create {
    my $class = shift;
    my %args = @_;

    # Roles inject methods, so we can't call SUPER. :(
    my $self = $class->Test::Builder2::Mouse::Object::new(@_);

    # Store our constructor arguments
    $self->_coordinator_constructor_args(\%args);

    $self->_add_coordinator;

    return $self;
}


sub _add_coordinator {
    my $self = shift;

    my $coordinator_class = $self->coordinator_class;
    $self->load( $coordinator_class );

    my $ec = $coordinator_class->create( %{ $self->_coordinator_constructor_args } );

    push @{ $self->_coordinators }, $ec;

    $self->_delegate_to;

    return;
}


# Convince isa() that we act like an EventCoordinator
sub isa {
    my($self, $want) = @_;

    my $ec = $self->_coordinators->[0];
    return $ec->isa($want) if $ec;
    return $self->SUPER::isa($want);
}


sub can {
    my($self, $want) = @_;

    my $ec = $self->_coordinators->[0];
    return $ec->can($want) if $ec;
    return $self->SUPER::can($want);
}


sub _delegate_to {
    my $self  = shift;

    my $delegate = $self->_coordinators->[0];
    my $meta = $self->meta;
    foreach my $name( $delegate->meta->get_all_method_names ) {
        # Check what we can do without the delegate.
        # And don't redelegate
        next if $self->SUPER::can($name);

        # Don't delegate private methods
        next if $name =~ /^_/;

        $meta->add_method($name => sub {
            my $self = shift;
            $self->_coordinators->[0]->$name(@_);
        });
    }

    return;
}

# Do not make it immutable.
no Test::Builder2::Mouse;

1;

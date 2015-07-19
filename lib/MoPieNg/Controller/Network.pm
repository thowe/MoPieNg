package MoPieNg::Controller::Network;
use Mojo::Base 'Mojolicious::Controller';

use NetAddr::IP qw(:lower);

=head2 branch

Display the portion of the tree under a specific network.

=cut

sub branch {
  my $self = shift;
  my $id = $self->param('id');
  $self->stash( 'message' => $self->flash('message') );

  my $network = $self->piedb->resultset('Network')->find({ 'id' => $id });

  if( not defined $network ) {
      $self->flash( 'message' => "No network with that id." );
      $self->redirect_to('networkroots');
  }

  if( $network->subdivide ) { 
      $self->stash( 'network' => $network );
      $self->stash( 'branch' => $network->branch_with_space );
  }
  elsif( $network->parent and $network->parent->subdivide ) {
      $self->redirect_to( 'networkbranch', 'id' => $network->parent->id );
  }
  else {
      $self->flash( 'message' => "No valid branch for that network." );
      $self->redirect_to( 'networkroots' );
  }
}

=head2 roots

Display a list of the base networks.
to the list.

=cut

sub roots {
  my $self = shift;

  my $roots_rs = $self->piedb->resultset('Network')->search(
                    { parent => undef } );
  $self->stash( 'roots' => $roots_rs );
  $self->stash( 'message' => $self->flash('message') );
}

1;

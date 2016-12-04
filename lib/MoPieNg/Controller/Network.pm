package MoPieNg::Controller::Network;
use Mojo::Base 'Mojolicious::Controller';

use NetAddr::IP qw(:lower);

=head2 add

Add a network if POST, or display a creation form if GET.

=cut

sub add {
  my $self = shift;

  my $id = $self->param('id');
  my $user = $self->piedb->resultset('User')->find(
                         { 'id' => $self->session('user') } );
  my $parent_id;  # will remain undef for roots
  my $parent;     # a Network instance
  my $path = $self->req->url->path;

  # we don't want to get redirected back to ourself
  my $referrer = $self->param('referrer');
  $referrer ||= Mojo::URL->new($self->req->headers->referrer)->path;
  $referrer = $self->url_for('networkroots') if $referrer =~ /$path/;

  $self->stash('referrer' => $referrer);

  # If not authorised, drop back to the referring page.
  if( not $user->has_role_any( qw/ administrator creator / ) ) {
    $self->flash('message' => "You are not authorized to create contracts.");
    $self->redirect_to($referrer);
    return;
  }

  # Handle URI arguments.
  if( $id eq 'root' ) {
      # used by the form
      $self->stash('parent_id' => 'root');
  }
  elsif( $id =~ /\A\d+\z/ ) {
    $parent = $self->piedb->resultset('Network')->find({
              id => $id });
    if( !defined $parent ) {
      $self->flash('message' => "No parent network with that id.");
      $self->redirect_to($referrer);
      return;
    }
    $parent_id = $id;
    $self->stash('parent_id' => $id);
    $self->stash('parent_network' => $parent);
  }
  else {
    $self->flash('message' => 'somethin screwy going on here');
    $self->redirect_to($referrer);
    return;
  }

  my $config = $self->app->this_site_config;

  if( $id ne 'root' ) {
    $self->stash( 'fsfirst' => $self->param('fsfirst') );
    $self->stash( 'fslast'  => $self->param('fslast') );
    $self->stash( 'rmask'   => $self->param('rmask') );
    my $freespace = PieDB::FreeSpace->new( {
        first_ip => NetAddr::IP::Lite->new($self->param('fsfirst')),
        last_ip => NetAddr::IP::Lite->new($self->param('fslast')),
        subnet => $parent->net_addr_ip } );

    $self->stash( 'fillnets' => $freespace->fillnets(
                                $self->param('rmask'),
                                $config->{'fillnet_limit'}) );
  }

  if( $self->req->method eq 'POST' ) {
    my @masks;
    if( $self->param('valid_masks') ) {
      @masks = $self->param('valid_masks') =~ /(\d+)/g;
      @masks = sort {$a <=> $b} @masks;
    }

    # Is the network a valid network?  (meaning Net::Addr::IP thinks so)
    my $netaddrip;
    if( $self->param('selected_address_range') and
        $self->param('selected_address_range') eq 'manual_input' and
        $self->param('address_range') ) {

      $netaddrip = NetAddr::IP::Lite->new($self->param('address_range'));
    }
    elsif( defined $self->param('selected_address_range') ) {
      $netaddrip = NetAddr::IP::Lite->new(
                       $self->param('selected_address_range') );
    }
    elsif( defined $self->param('address_range') ) {
      $netaddrip = NetAddr::IP::Lite->new($self->param('address_range'));
    }
    if(!defined $netaddrip) {
      $self->stash('message' => $self->param('address_range') .
                               " is not a valid network.");
      return;
    }

    my $new_network = $self->piedb->resultset('Network')->new({
        parent        => $parent_id,
        address_range => $netaddrip->cidr,
        description   => $self->param('description'),
        subdivide     => $self->param('subdivide'),
        valid_masks   => \@masks,
        owner         => $self->param('owner'),
        account       => $self->param('account'),
        service       => $self->param('service') eq '' ?
                         undef : $self->param('service') });

    # Masks are always considered logical if we are not subdividing.
    if( not $new_network->masks_are_logical ) {
      $self->stash('message' => $self->param('valid_masks') .
                               " aren't logical masks here." );
      return;
    }

    # If it is a root, does it already overlap with another network
    # in the database?
    if( $id eq 'root' and $new_network->overlaps_any) {
      $self->stash('message' => $self->param('address_range') .
          " can't be a root; it overlaps with another network.");
      return;
    }
    if( $id ne 'root' ) {
      # Can the parent be subdivided?
      if( not $parent->subdivide ) {
        $self->stash('message' => $self->params('address_range') .
            " can't be added while the parent can't be subdivided.");
        return;
      }
      # Does the parent network allow this length of mask?
      if( not grep { $_ == $netaddrip->masklen } @{$parent->valid_masks} ){
        $self->stash('message' => "The parent doesn't allow this mask length");
        return;
      }
      # Does the specified network overlap at this level of the tree?
      if($new_network->overlaps) {
        $self->stash('message' => $self->param('address_range') .
            " overlaps with another network at this level.");
        return;
      }
      # Is the specified parent the right place for this in the hierarchy?
      if( not ($parent->net_addr_ip ==
               $new_network->smallest_container->net_addr_ip) ) {
        $self->stash('message' => $self->param('address_range') .
            " doesn't belong in this part of the tree");
        return;
      }
    }

    # Stick it in the database.
    $new_network->insert;

    ## Add our creation to the changelog.
    #$c->stash->{'prefix'} = $new_network->cidr_compact;
    #$c->stash->{'changed_cols'} = { $new_network->get_columns };
    #$c->stash->{'log_type'} = 'created';
    #$c->forward('/logs/netlog');

    $self->helpers->netlog(
        $new_network->cidr_compact,
        'created',
        { $new_network->get_columns }
    );

    $self->redirect_to($referrer);
  }
}

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

=head2 search

Search through the networks for a particular string, which may be                
an IP address, a network, or any other part of a record.

=cut

sub search {
  my $self = shift;
}

1;

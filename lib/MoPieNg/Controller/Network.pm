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
  $referrer //= $self->param('refp');
  $referrer = $self->url_for('networkroots') if $referrer =~ /$path/;

  $self->stash('referrer' => $referrer);

  # If not authorised, drop back to the referring page.
  if( not $user->has_role_any( qw/ administrator creator / ) ) {
    $self->flash('message' => "You are not authorized to create networks.");
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
        $self->stash('message' => $self->param('address_range') .
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

    # Add our creation to the changelog.
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
      $self->redirect_to( 'networkbranchid', 'id' => $network->parent->id );
  }
  else {
      $self->flash( 'message' => "No valid branch for that network." );
      $self->redirect_to( 'networkroots' );
  }
}

=head2 edit



=cut

sub edit {
  my $self = shift;
  my $id = $self->param('id');
  my $user = $self->piedb->resultset('User')->find(
                         { 'id' => $self->session('user') } );
  my $path = $self->req->url->path;

  # we don't want to get redirected back to ourself
  my $referrer = $self->param('referrer');
  $referrer //= $self->param('refp');
  $referrer = $self->url_for('networkroots') if $referrer =~ /$path/;

  $self->stash('referrer' => $referrer);

  # If not authorised, drop back to the referring page.
  if( not $user->has_role_any( qw/ administrator creator editor / ) ) {
    $self->flash('message' => "You are not authorized to edit networks.");
    $self->redirect_to($referrer);
    return;
  }

  # Find the network or go back to roots.
  my $network = $self->piedb->resultset('Network')->find({ 'id' => $id });
  if( not defined $network ) {
      $self->flash( 'message' => "No network with that id." );
      $self->redirect_to('networkroots');
  }
  $self->stash( 'network' => $network );

  # When/if the form is submitted.
  if( $self->req->method eq 'POST' ) {
    my @masks;
    if( $self->param('valid_masks') ) {
      @masks = $self->param('valid_masks') =~ /(\d+)/g;
      @masks = sort {$a <=> $b} @masks;
    }

    if( $self->param('service') and $self->param('service') ne '' and
        $self->param('service') =~ m/[^0-9.]/ ) {

      $self->flash( 'message' => "Service ID should be an integer." );
      $self->redirect_to($referrer);
      return;
    }

    $network->set_columns({
                description => $self->param('description'),
                subdivide   => $self->param('subdivide'),
                valid_masks => \@masks,
                owner       => $self->param('owner'),
                account     => $self->param('account'),
                service     => $self->param('service') eq '' ?
                                   undef : $self->param('service') });

    my %changed_cols = $network->get_dirty_columns;

    # We don't want to exclude existing children when changing valid_masks.
    if( defined $changed_cols{'valid_masks'} and $network->subdivide and
        $network->has_children ) {
      my @net_children = $network->networks;
      foreach my $child (@net_children) {
        if( ! grep {$_ eq $child->net_addr_ip->masklen} @{$network->valid_masks} ) {
          $self->stash( 'message' =>
            "You can't change your masks to exclude an existing child.");
            return;
        }
      }
    }

    # Do we have logical masks? (always true if we aren't subdividing)
    if( ! $network->masks_are_logical ) {
      $self->stash('message' => $self->param('valid_masks') .
                                " aren't logical netmasks here.");
      return;
    }

    $network->update;

    # Add our updates to the changelog, but only if there are any.
    if( keys(%changed_cols) ) {
      $self->flash('prefix' => $network->cidr_compact);
      $self->flash('changed_cols' => \%changed_cols);
      $self->flash('log_type' => 'updated');

      # Add our edits to the changelog.
      $self->helpers->netlog(
        $network->cidr_compact,
        'edited',
        { $network->get_columns }
      );

      $self->flash('message' => $network->address_range . ' edited');
    }

    $self->redirect_to($referrer);
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

  return if( uc $self->req->method ne 'POST' );


  my $term = $self->param('term');
  $self->stash('searched_term' => $term);

  my $search_rs;

  # If we are just searching for an integer, let's assume it's a service id
  # before searching for it elsewhere.  Since a plain integer will look like
  # a valid address, we need to do this first.  It could also be part of a
  # owner name or description.  Plain integers will almost certainly not
  # be searched for as an IP address.
  if( $term =~ /\A\d+\z/ and
      ($search_rs = $self->piedb->resultset('Network')->search(
         [{ 'service' => $term},
          { 'owner' => { '-like' => ['%' . $term . '%'] }},
          { 'description' => { '-like' => ['%' . $term . '%'] }},
          { 'account' => $term } ],
          {} ))->count > 0 ) {
    $self->stash('networks' => [$search_rs->all]);
    return;
  }

  # Next we'll search for the account.  Since I am not sure what folks
  # may use for account numbers/IDs, we'll also get it out of the way before
  # searching networks since they could very well appear to be valid
  # addresses to NetAddr::IP::Lite.
  if(($search_rs = $self->piedb->resultset('Network')->search(
          { 'account' => $term}, {} ))->count > 0 ) {
    $self->stash('networks' => [$search_rs->all]);
    return;
  }

  # Is the search term a valid network? (meaning Net::Addr::IP thinks so)
  # If so, we will search the db for a network containing the term.
  # If not, we will search the other network attributes.
  my $netaddrip;
  $netaddrip = NetAddr::IP::Lite->new($term);
  if( defined $netaddrip ) {

    # NetAddr::IP will accept more variations of input than will PostgreSQL.
    # We will need to sanitize it a bit to make sure it is really valid
    # for Pg.  We do this with the same logic as in our Network class.
    # I should probably derive a new object from NetAddr::IP::Lite and define
    # a method to do this.
    my $compact_cidr;
    if( $netaddrip->version == 4) {
      $compact_cidr = $netaddrip->cidr;
    }
    else {
      $compact_cidr =  $netaddrip->short . '/' . $netaddrip->masklen;
    }

    $search_rs = $self->piedb->resultset('Network')->search(
        { 'address_range' => { '>>=',  $compact_cidr},
          'subdivide' => 'f' }, {} );

    $self->stash('networks' => [$search_rs->all]);
    return;
  }

  if( ($search_rs = $self->piedb->resultset('Network')->search(
         [{ 'owner' => { '-ilike' => ['%' . $term . '%'] }},
          { 'description' => { '-ilike' => ['%' . $term . '%'] }}, ],
          {} ))->count > 0 ) {
    $self->stash('networks' => [$search_rs->all]);
    return;
  }

}

1;

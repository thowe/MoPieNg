package MoPieNg::Controller::User;
use Mojo::Base 'Mojolicious::Controller';

sub verify_authenticated {
    my $self = shift;

    if( defined $self->session('user') ) {
      return 1;
    }
    else {
      $self->flash('requested' => $self->req->url->to_abs->path);
      $self->redirect_to('/login');
      return;
    }
}

sub add {
  my $self = shift;
}

=head2 edit

=cut

sub edit {
  my $self = shift;
  my $path = $self->req->url->path;
  my $user = $self->piedb->resultset('User')->find(
                         { 'id' => $self->session('user') } );

  # we don't want to get redirected back to ourself
  my $referrer = $self->param('referrer');
  $referrer ||= Mojo::URL->new($self->req->headers->referrer)->path;
  $referrer = $self->url_for('userlist') if $referrer =~ /$path/;

  $self->stash('referrer' => $referrer);
  my $edituser = $self->piedb->resultset('User')->find(
                          { id => $self->param('id') } );

  if( not defined $edituser ) {
    $self->flash('message' => "No such user id.");
    $self->redirect_to($referrer);
    return;
  }
  $self->stash('edituser' => $edituser);

  # If not authorised, drop back to the referring page.
  if( not $user->has_role_any( qw/ administrator / ) ) {
    $self->flash('message' => "You are not authorized to edit users.");
    $self->redirect_to($referrer);
    return;
  }

    # If the edit form has actually been submitted...
    if(lc $self->req->method eq 'post') {
#
#            if(!Email::Valid->address($params->{email})) {
#                $c->stash->{'message'} = $params->{email} . " is not a valid email address.";
#                return;
#            }
#
#            # if our passwords match up
#            if($params->{password1} eq $params->{password2} &&
#               length $params->{password1} > 2) {
#
#                eval { $edituser->update({
#                    email    => $params->{email},
#                    password => $params->{password1},
#                    status   => $params->{status} }) };
#
#                my $role = $c->model('PieDB::Role')->find(
#                                     { name => $params->{role} } );
#                $edituser->user_roles->delete();
#                $edituser->user_roles->create({ role => $role->id });
#
#                # If we get to this point the user should have been updated.
#                $c->flash->{'message'} = "Updated user " . $params->{username};
#                # Let's head over to our user list to make sure...
#                $c->response->redirect($c->uri_for(
#                        $c->controller('Users')->action_for('list')));
#                $c->detach();
#            }
#            else {
#                $c->stash->{'message'} = "Password mismatch or too short."
#            }
#
#        }
#        else {
#            $c->stash->{'message'} = "You are not an administrator."
#        }
#
#    }
#    else {
#        # If we are just going to display the user edit form, we
#        # will give it the user to edit.
#        $c->stash->{'edituser'} = $edituser;
    }
}

=head2 list

List the user records.

=cut

sub list {
  my $self = shift;

  my @list = $self->piedb->resultset('User')->search(
                          undef, { order_by => 'username' } );
  $self->stash( 'users' => @list );
  $self->stash( 'message' => $self->flash('message') );
}

sub login {
    my $self = shift;

    if( $self->req->method ne 'POST' ) {

        # We would like to redirect to the requested URI after login.
        if( defined $self->flash('requested') ){
            $self->stash('requested' => $self->flash('requested'));
        }
        else {
            $self->stash('requested' => '/');
        }

        $self->render;
        return;
    }
    else {
        my $user = $self->param('username');
        my $pass = $self->param('password');

        # Default to root so we don't end up at the login page again.
        my $requested = '/';
        if( defined $self->param('requested') ) {
          $requested = $self->param('requested')
        }

        my $dbuser = $self->piedb->resultset('User')->find(
                         { 'username' => $user } );

        if( not $dbuser ) {
            $self->stash( 'error' => "Username $user doesn't seem to exist." );
            $self->stash('requested' => $requested);
            return;
        }

        if( $dbuser->match_password($pass) ) {
            $self->session( 'user' => $dbuser->id );
            $self->redirect_to($requested);
        }
    }
}

sub logout {
    my $self = shift;
    $self->session('expires' => 1);
    $self->redirect_to('/');
}

1;

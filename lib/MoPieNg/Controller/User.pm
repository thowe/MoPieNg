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

=head2 edit

=cut

sub edit {
    my $self = shift;

    # Use the argument passed in (which should be the
    # id of a user record).  The argument could also be
    # supplied by $c->req->args->[0] .
#    my $edituser = $c->model('PieDB::User')->find(
#                                     { id => $id } );
#    if(!defined $edituser) {
#        $c->stash->{'message'} = "No such user id.";
#        return;
#    }

    # If the edit form has actually been submitted...
#    if(lc $c->req->method eq 'post') {
#        # if we are doing so as an administrator
#        if($c->check_user_roles( qw/ administrator / )) {
#            my $params = $c->req->params;
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
#    }
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


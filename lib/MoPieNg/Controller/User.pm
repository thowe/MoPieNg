package MoPieNg::Controller::User;
use Mojo::Base 'Mojolicious::Controller';

sub verify_authenticated {
    my $self = shift;

    if( $self->session->{'user'} ) {
      return 1;
    }
    else {
      $self->flash('requested' => $self->req->url->to_abs->path);
      $self->redirect_to('/login');
      return;
    }
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
        my $requested = $self->param('requested');

        my $dbuser = $self->piedb->resultset('User')->find(
                         { 'username' => $user } );

        if( not $dbuser ) {
            $self->stash( 'error' => "Username $user doesn't seem to exist." );
            $self->stash('requested' => $requested);
            return;
        }

        if( $dbuser->match_password($pass) ) {
            $self->session->{'user'} = $dbuser->id;
            $self->redirect_to($requested);
        }
    }
}

sub logout {
    my $self = shift;
    $self->session('expires' => 1);
    $self->redirect_to('/');
    return;
}

1;


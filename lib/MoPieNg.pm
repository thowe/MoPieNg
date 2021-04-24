package MoPieNg;
use Mojo::Base 'Mojolicious';

use PieDB::Schema;

# This method will run once at server start
sub startup {
  my $self = shift;

  # Documentation browser under "/perldoc"
  #$self->plugin('PODRenderer');

  push @{$self->commands->namespaces}, 'MoPieNg::Command';

  # Mojolicious::Plugin::Config
  $self->helper('this_site_config' => sub { $self->plugin('Config') } );

  # Database
  $self->helper(piedb => sub {
      my $config = $self->plugin('Config');
      return PieDB::Schema->connect(
          $config->{'dbi'},
          $config->{'db_user'},
          $config->{'db_pass'},
          $config->{'dbi_attributes'},
          $config->{'extra_attributes'}, )
                       }
               );

  # Changelog helper
  $self->helper('netlog' => \&netlog);

  # Router
  my $r = $self->routes;

  # /login
  $r->any([qw (GET POST)] => '/login')->to('user#login');
  $r->get('/logout')->to('user#logout');

  # Everything other than login and logout must first verify an
  # authenticated user.
  my $root = $r->under('/')->to('user#verify_authenticated');

  # Normal route to controller
  $root->get('/')->to('network#roots');

  $root->get('/network/roots')->to('network#roots');
  $root->get('/network/branch/:id')->to('network#branch');
  $root->any([qw (GET POST)] => '/network/edit/:id')->to('network#edit');
  $root->any([qw (GET POST)] => '/network/search')->to('network#search');
  $root->any([qw (GET POST)] => '/network/add/:id')->to('network#add');

  $root->get('/log')->to('log#index');

  $root->get('/user/list')->to('user#list');
  $root->get('/user/edit/:id')->to('user#edit');
}

=head2 netlog
netlog is called when a change to a record is successful.
It logs the change with the changed columns in a JSON structure
=cut

sub netlog {
  use Mojo::JSON qw( encode_json );
  my ($c, $prefix, $log_type, $cols) = @_;

  my $user_id = $c->session('user');

  my $new_changelog = $c->helpers->piedb->resultset('Changelog')->new({
                            'user'   => $user_id,
                            'prefix' => $prefix,
                            'change' => encode_json({ $log_type => $cols }) });
  $new_changelog->insert;
}

1;

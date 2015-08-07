package MoPieNg;
use Mojo::Base 'Mojolicious';

use PieDB::Schema;

# This method will run once at server start
sub startup {
  my $self = shift;

  # Documentation browser under "/perldoc"
  $self->plugin('PODRenderer');

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
  $root->any([qw (GET POST)] => '/network/add/:id')->to('network#add');
  

  $root->get('/user/list')->to('user#list');
  $root->get('/user/edit/:id')->to('user#edit');
}

1;


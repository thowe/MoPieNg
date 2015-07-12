package MoPieNg::Command::admin_pass;
use Mojo::Base 'Mojolicious::Command';

use PieDB::Schema;

has description => "Set the admin user's password.";
has usage       => "Usage: script/mo_pie_ng admin_pass NEW_PASSWORD\n";

sub run {
  my ($self, @args) = @_;

  if( not defined $args[0] ) { die "You must specify a password.\n" };

  my $admin_pass = $args[0];
  my $admin_user = 'admin';

  my $config = $self->app->this_site_config;
  my $schema = $self->app->piedb;

  my $admin = $schema->resultset('User')->find({
                  username => $admin_user });

  if (defined $admin) {
    $admin->set_encrypted_password($admin_pass);
  }
  else {
    $admin = $schema->resultset('User')->create({
                username => $admin_user,
                password => $admin_pass });
    my $role = $schema->resultset('Role')->find(
                   { name => 'administrator' });
    $admin->user_roles->create({ role => $role->id });
  }
}

1;

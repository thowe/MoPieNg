use utf8;
package PieDB::Schema::Result::User;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

PieDB::Schema::Result::User

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 COMPONENTS LOADED

=over 4

=item * L<DBIx::Class::InflateColumn::DateTime>

=back

=cut

__PACKAGE__->load_components("InflateColumn::DateTime");

=head1 TABLE: C<users>

=cut

__PACKAGE__->table("users");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'users_id_seq'

=head2 username

  data_type: 'varchar'
  is_nullable: 0
  size: 32

=head2 password

  data_type: 'text'
  is_nullable: 0

=head2 email

  data_type: 'text'
  is_nullable: 1

=head2 status

  data_type: 'integer'
  default_value: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "users_id_seq",
  },
  "username",
  { data_type => "varchar", is_nullable => 0, size => 32 },
  "password",
  { data_type => "text", is_nullable => 0 },
  "email",
  { data_type => "text", is_nullable => 1 },
  "status",
  { data_type => "integer", default_value => 1, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<users_username_key>

=over 4

=item * L</username>

=back

=cut

__PACKAGE__->add_unique_constraint("users_username_key", ["username"]);

=head1 RELATIONS

=head2 changelogs

Type: has_many

Related object: L<PieDB::Schema::Result::Changelog>

=cut

__PACKAGE__->has_many(
  "changelogs",
  "PieDB::Schema::Result::Changelog",
  { "foreign.user" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 user_roles

Type: has_many

Related object: L<PieDB::Schema::Result::UserRole>

=cut

__PACKAGE__->has_many(
  "user_roles",
  "PieDB::Schema::Result::UserRole",
  { "foreign.user" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 roles

Type: many_to_many

Composing rels: L</user_roles> -> role

=cut

__PACKAGE__->many_to_many("roles", "user_roles", "role");


# Created by DBIx::Class::Schema::Loader v0.07043 @ 2015-07-12 14:12:39
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Vgey0OGoTSXSu/QheJHBww

use Authen::Passphrase::BlowfishCrypt;

=head2 has_role

=cut

sub has_role {
    my ($self, $role) = @_;
    my $roles = $self->user_roles->find({ role_id => $role->id });
    return $roles; # should be undef if nothing found
}

=head2 has_role_name

=cut

sub has_role_name {
    my ($self, $rolename) = @_;
    my $roles = $self->user_roles->search_related(
                                   'role', { name => $rolename });
    return $roles->count();
}

sub match_password {
    my ($self, $plain) = @_;

    my $epp = Authen::Passphrase::BlowfishCrypt->from_crypt(
                  $self->password);

    return $epp->match($plain);
}

=head2 set_encrypted_password

This takes a plain text passphrase and hashes it using bcrypt.

=cut

sub set_encrypted_password {
    my ($self, $plain) = @_;

    my $epp = Authen::Passphrase::BlowfishCrypt->new(
                   cost => 6, salt_random => 1,
                   passphrase => $plain);
    $self->password($epp->as_crypt);
    $self->update;
}

1;

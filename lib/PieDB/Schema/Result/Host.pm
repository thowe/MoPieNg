use utf8;
package PieDB::Schema::Result::Host;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

PieDB::Schema::Result::Host

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

=head1 TABLE: C<hosts>

=cut

__PACKAGE__->table("hosts");

=head1 ACCESSORS

=head2 address

  data_type: 'inet'
  is_nullable: 0

=head2 network

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 description

  data_type: 'text'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "address",
  { data_type => "inet", is_nullable => 0 },
  "network",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "description",
  { data_type => "text", is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</address>

=back

=cut

__PACKAGE__->set_primary_key("address");

=head1 RELATIONS

=head2 network

Type: belongs_to

Related object: L<PieDB::Schema::Result::Network>

=cut

__PACKAGE__->belongs_to(
  "network",
  "PieDB::Schema::Result::Network",
  { id => "network" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07043 @ 2015-07-12 14:12:39
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:i8A00438O+b+rCxDxVzLag


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;

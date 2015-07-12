use utf8;
package PieDB::Schema::Result::Changelog;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

PieDB::Schema::Result::Changelog

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

=head1 TABLE: C<changelog>

=cut

__PACKAGE__->table("changelog");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'changelog_id_seq'

=head2 user

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 change_time

  data_type: 'timestamp'
  default_value: current_timestamp
  is_nullable: 0
  original: {default_value => \"now()"}

=head2 prefix

  data_type: 'inet'
  is_nullable: 0

=head2 change

  data_type: 'text'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "changelog_id_seq",
  },
  "user",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "change_time",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "prefix",
  { data_type => "inet", is_nullable => 0 },
  "change",
  { data_type => "text", is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 user

Type: belongs_to

Related object: L<PieDB::Schema::Result::User>

=cut

__PACKAGE__->belongs_to(
  "user",
  "PieDB::Schema::Result::User",
  { id => "user" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07043 @ 2015-07-12 14:12:39
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:/QeW0Cu7yYJ4v94kmCYNgQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;

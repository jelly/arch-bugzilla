#!/usr/bin/perl -w

use warnings;
use strict;
use feature "switch";

use POSIX qw(strftime);

# db info
our $ROOT_HOST = 'localhost';
our $ROOT_USER = 'root';
our $ROOT_PASS = '';

# flyspray info
our $FS_DB = 'flyspray';
our $FS_PFX = 'flyspray_';
our $FS_ATTACH = '/root/attachments/';

# bugzilla info
our $BZ_DB = 'bugzilla';
our $BZ_UNKNOWN_USER = 2;		#userid
our $BZ_NEEDSINPUT_KEYWORD = 1;		#keyword for "needsinput"

# no need to edit below
use DBI;
my $dsn = "DBI:mysql:$FS_DB:$ROOT_HOST";
our $dbh = DBI->connect($dsn, $ROOT_USER, $ROOT_PASS);

our ($last_insert_id, $mvtab_add, $mvtab_find);
$last_insert_id = $dbh->prepare("SELECT LAST_INSERT_ID()");
$mvtab_add = $dbh->prepare("REPLACE INTO $FS_DB.${FS_PFX}mvtab (type, old_id, new_id) VALUES (?, ?, ?)");
$mvtab_find = $dbh->prepare("SELECT new_id FROM $FS_DB.${FS_PFX}mvtab WHERE old_id = ? AND type = ?");

populate_fs_users();

sub ins_id
{
	my ($id);

	$last_insert_id->execute();
	($id) = $last_insert_id->fetchrow_array();

	return $id;
}

sub populate_fs_users
{
	my ($user_id, $user_name, $real_name);
	my ($email, $bz_userid);

	# TODO where account_enabled != 0
	my $sth = $dbh->prepare("SELECT user_id, user_name, real_name, email_address FROM $FS_DB.${FS_PFX}users");
	my $bz_find_user = $dbh->prepare("SELECT userid FROM $BZ_DB.profiles WHERE login_name = ?");
	my $bz_add_user = $dbh->prepare("INSERT INTO $BZ_DB.profiles (login_name, realname) VALUES (?, ?)");

	# Find all Flyspray users.
	$sth->execute();
	while ( ($user_id, $user_name, $real_name, $email) = $sth->fetchrow_array() )
	{
		# FIXME: verify if the email address is valid, since it's not always the case

		# See if this user is already in bugzilla.
		$bz_find_user->execute($email);
		if ( ($bz_userid) = $bz_find_user->fetchrow_array() )
		{
			# Re-populate just in-case.
			$mvtab_add->execute('user', $user_id, $bz_userid);
		}
		else
		{
			$bz_add_user->execute($email, $real_name);
			$bz_userid = ins_id();
			$mvtab_add->execute('user', $user_id, $bz_userid);
			print STDERR "Binding ($user_id, \"$user_name\") to ($bz_userid, $email)\n";
		}
	}

	$sth->finish();
	$bz_find_user->finish();
	$bz_add_user->finish();
}

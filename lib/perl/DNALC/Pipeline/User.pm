package DNALC::Pipeline::User;

use strict;
use warnings;

use base qw(DNALC::Pipeline::DBI);

use POSIX ();
use Digest::MD5 ();
use DNALC::Pipeline::Utils qw(random_string);

#use DNALC::Pipeline::UserProfile ();

{
	my $salt = 'bdb6896bf6e4c2d466a2c9f91d0e99bc'; # do not edit

	__PACKAGE__->table('users');
	__PACKAGE__->columns(Primary => 'user_id');
	__PACKAGE__->columns(Essential => qw/username email password name_first name_last/);
	__PACKAGE__->columns(Others => qw/created login_num/);
	__PACKAGE__->sequence('users_user_id_seq');

	__PACKAGE__->add_trigger(before_create => sub {
	    $_[0]->{created} ||= POSIX::strftime "%Y-%m-%d %H:%M:%S", localtime(+time);
	});

	__PACKAGE__->add_trigger(before_create  => \&crypt_password);

	__PACKAGE__->has_many(roles => 'DNALC::Pipeline::UserRole');


	sub full_name {
		my ($self) = @_;
		$self->name_first . ' ' . $self->name_last;
	}

	sub groups { 
		my $self = shift;
		return [ map $_->group_id->id, $self->roles ];
	}

	sub add_to_group {
		my ($self, $g) = @_;

		$self->add_to_roles( {
					user_id => $self,
					group_id => $g 
				});
	}

	# unsubscribe user from given group
	sub remove_from_group {
		my ($self, $gid) = @_;
		
		my $r = DNALC::Pipeline::UserRole->retrieve(uid => $self->id, gid => $gid);
		$r->delete if $r;
	}


	sub crypt_password {
		my ($self) = @_;

		my $md5 = Digest::MD5->new;
		$md5->add($self->{email}, $self->{password}, $salt);
		$self->{password} = $md5->hexdigest;
	}

	sub password_valid {
		my ($self, $plain_password) = @_;
		
		my $md5 = Digest::MD5->new;
		$md5->add($self->email, $plain_password, $salt);
		my $cp = $md5->hexdigest;

		return $self->password eq $cp;
	}

	#--------------------------------------------------
	sub create_reset_pwd_code {
		my ($self) = @_;
		my $tries = 10;
		while ($tries--) {
			my $code = random_string(8,8);
			my $rp = $self->get_user_by_reset_pwd_code( $code );
			return $code unless $rp;
		}
	}

	#--------------------------------------------------
	__PACKAGE__->set_sql(user_by_code => <<'');
	SELECT uid
	FROM user_reset_pwd
	WHERE code = ?


	sub get_user_by_reset_pwd_code {
		my ($class, $code) = @_;

		my $sth = $class->sql_user_by_code;
		$sth->execute($code);
		my $iter = $class->sth_to_objects($sth);
		return $iter->next if $iter;
	}

	sub reset_pwd_code_exists {
		my ($class, $code) = @_;

		return $class->search_user_by_code($code);
	}

	#--------------------------------------------------
	__PACKAGE__->set_sql( insert_code => <<'');
	INSERT INTO user_reset_pwd
	(uid, code) VALUES (?, ?)

	sub set_reset_pwd_code {
		my ($self, $code) = @_;
		my $sth = __PACKAGE__->sql_insert_code;
		$sth->execute($self->uid, $code);
	}

	#--------------------------------------------------
	__PACKAGE__->set_sql( delete_code => <<'');
	DELETE FROM user_reset_pwd
	WHERE uid = ?

	sub clear_reset_pwd_code {
		my ($self, $code) = @_;
		my $sth = __PACKAGE__->sql_delete_code;
		$sth->execute($self->uid);
	}

	#--------------------------------------------------
}

1;

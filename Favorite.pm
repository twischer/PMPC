package Favorite;
use strict;
use warnings;
use utf8;
use Storable();
require MPDCtrl;

########################################################################################################################
sub new
########################################################################################################################
{
	my ($proto, $pobjConfig) = @_;
	
	my $self  = {};
		
	my $class = ref($proto) || $proto;
	bless ($self, $class);
	
	$self->{pobjConfig} = $pobjConfig;
	$self->{paszFavorite} = [];
	
	
	$self->{szFavoriteFile} = $pobjConfig->GetFavoriteFile();
	if ( -f $self->{szFavoriteFile} )
	{
		push @{ $self->{paszFavorite} }, sort @{  Storable::retrieve( $self->{szFavoriteFile} )  };
		
		Logger->GetInstance()->Write( $self, 3, "All tracks:\n" . join("\n", @{ $self->{paszFavorite} }) );
	}
	
	return $self;
}

########################################################################################################################
sub delete
########################################################################################################################
{
	my ($self) = @_;
	
	Storable::store( $self->{paszFavorite}, $self->{szFavoriteFile} );
}

########################################################################################################################
sub add
########################################################################################################################
{
	my ($self, $szSong) = @_;
	

	if ($szSong ne "")
	{
		unless (  $self->IsInArray( $self->{paszFavorite}, $szSong )  )
		{
			push @{ $self->{paszFavorite} }, $szSong;
		}
		else
		{
			return "FAVORITE_SONG_ALREADY_IN_LIST";
		}
	}
	else
	{
		return "FAVORITE_NO_SONG_SELECTED";
	}
	
	return "DONE";
}

########################################################################################################################
sub remove
########################################################################################################################
{
	my ($self, $szSong) = @_;
	

	if ($szSong ne "")
	{
		my @aszTempFavorite = @{ $self->{paszFavorite} };
	
		$self->{paszFavorite} = [];
		foreach my $szItem (@aszTempFavorite)
		{
			if ($szItem ne $szSong)
			{
				push @{ $self->{paszFavorite} }, $szItem;
			}
		}
		
		return "DONE";
	}
	else
	{
		return "FAVORITE_NO_SONG_SELECTED";
	}
}

########################################################################################################################
sub IsInArray
########################################################################################################################
{
	my ($self, $paszData, $szData) = @_;
	
	foreach (@$paszData)
	{
		if ($szData eq $_)
		{
			return 1;
		}
	}
	
	return 0;
}

########################################################################################################################
sub GetFavoriteFiles
########################################################################################################################
{
	my ($self) = @_;
	
	my @aszDevices = ();
	my $szConfigDir = $self->{pobjConfig}->GetConfigDir();
	opendir( my $hDir, $szConfigDir ) or Logger->GetInstance()->Write($self, 1, "Could not get the favorite file list from the directory: $!!");
	foreach my $szDir (  readdir( $hDir )  )
	{
		if ($szDir =~ m/^favorite.*\.dat/i)
		{
			push @aszDevices, $szDir;
		}
	}
	closedir( $hDir );
	
	return @aszDevices;
}

########################################################################################################################
sub get
########################################################################################################################
{
	my ($self) = @_;
	
	return $self->{paszFavorite};
}
1;

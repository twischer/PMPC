package Playlist;
use strict;
use warnings;
use utf8;
require Logger;
require MPDCtrl;
require Favorite;
require Charts;

########################################################################################################################
sub new
########################################################################################################################
{
	my ($proto, $pobjConfig) = @_;
	
	my $self  = {};
		
	my $class = ref($proto) || $proto;
	bless ($self, $class);
	
	$self->{pobjConfig} = $pobjConfig;
	$self->{paszPlaylist} = [];
	$self->{pobjFavorite} = Favorite->new($pobjConfig);
	$self->{pobjCharts} = Charts->new($pobjConfig);
	
	$self->AddRandomFileIfNeeded();
	$self->Update();
	
	return $self;
}

########################################################################################################################
sub delete
########################################################################################################################
{
	my ($self) = @_;
	
	$self->{pobjCharts}->delete();
	$self->{pobjFavorite}->delete();
}

########################################################################################################################
sub Update
########################################################################################################################
{
	my ($self) = @_;
	
	my $fUpdatePlaylist = 0;
	if (defined MPDCtrl->GetInstance()->GetMPD()->current)
	{
		while (MPDCtrl->GetInstance()->GetMPD()->current->pos > 0)
		{
			MPDCtrl->GetInstance()->GetMPD()->playlist->delete(0);
			$self->AddRandomFileIfNeeded();
			
			$fUpdatePlaylist = 1;
		}
	}
	
	return $fUpdatePlaylist;
}

########################################################################################################################
sub get
########################################################################################################################
{
	my ($self) = @_;
	

	my @aobjSongs = MPDCtrl->GetInstance()->GetMPD()->playlist->as_items();
	
	# Ersten Song nicht in der Playliste anzeigen, da er gerade gespielt wird
	shift @aobjSongs;
	my @aszSongs = map{ $_->file }@aobjSongs;

	return @aszSongs;
}

########################################################################################################################
sub Add
########################################################################################################################
{
	my ($self, $szFileName) = @_;
	
	if (  (MPDCtrl->GetInstance()->GetMPD()->status->playlistlength() - 1) < $self->{pobjConfig}->GetMaxPlaylistLength()  )
	{
		my $fFileAlreadyInList = 0;
		foreach my $pobjSong ( MPDCtrl->GetInstance()->GetMPD()->playlist->as_items() )
		{
			if ($szFileName eq $pobjSong->file)
			{
				$fFileAlreadyInList = 1;
				last;
			}
		}
		
		if ($fFileAlreadyInList)
		{
			return "PLAYLIST_EXISTS";
		}
		else
		{
			if (-f $self->{pobjConfig}->GetMusicDir() . "/" . $szFileName)
			{
				Logger->GetInstance()->Write($self, 2, "Add file '$szFileName'");
				MPDCtrl->GetInstance()->GetMPD()->playlist->add( $szFileName );
			}
			else
			{
				return "PLAYLIST_SONG_NOT_EXISTS";
			}
		}
	}
	else
	{
		return "PLAYLIST_FULL";
	}
	
	return "NONE";
}

########################################################################################################################
sub Move
########################################################################################################################
{
	my ($self, $nPos) = @_;
	
 	Logger->GetInstance()->Write($self, 2, "File in the playlist on position $nPos moves to top position.");
 	MPDCtrl->GetInstance()->GetMPD()->playlist->move( $nPos + 1, 1 );
}

########################################################################################################################
sub AddRandomFileIfNeeded
########################################################################################################################
{
	my ($self) = @_;
	
	while (MPDCtrl->GetInstance()->GetMPD()->status->playlistlength() <= 1)
	{
		my $szFileName = $self->GetRandomSong();
		if (defined $szFileName)
		{
			MPDCtrl->GetInstance()->GetMPD()->playlist->add( $szFileName );
			Logger->GetInstance()->Write($self, 2, "Add random song '$szFileName'");
		}
		else
		{
			Logger->GetInstance()->Write($self, 1, "Could not find a song in the MPD database!");
			last;
		}
	}
}

########################################################################################################################
sub GetRandomSong
########################################################################################################################
{
	my ($self) = @_;
	
	if ( $self->{pobjConfig}->GetUseCharts() )
	{
		my $nPlaylistLength = scalar @{ $self->{paszPlaylist} };
		if ($nPlaylistLength <= 0)
		{
			Logger->GetInstance()->Write($self, 2, "All songs of the charts and/or favorite lists were played.");
			
			$self->GenerateRandomPlaylist();
			$nPlaylistLength = scalar @{ $self->{paszPlaylist} };
		}
		
		Logger->GetInstance()->Write($self, 2, "Look for random song in charts and/or favorite lists ...");
		Logger->GetInstance()->Write($self, 3, "Random playlist length: $nPlaylistLength");
		
		my $nRand = int(  rand($nPlaylistLength)  );
		
		# Zufallssong aus der Playliste löschen und zurückgeben
		my $szRandomSong = splice(  @{ $self->{paszPlaylist} }, $nRand, 1  );
		return $szRandomSong;
	}
	else
	{
		Logger->GetInstance()->Write($self, 2, "Look for random song in music archive ...");
		
		return MPDCtrl->GetInstance()->GetRandomSong();
	}
}

########################################################################################################################
sub GenerateRandomPlaylist
########################################################################################################################
{
	my ($self) = @_;
	
	Logger->GetInstance()->Write($self, 2, "Loading charts and/or favorite lists ...");
	
	my %mpszPlaylist = ();
	foreach my $szListName ( $self->{pobjConfig}->GetChartsLists() )
	{
		Logger->GetInstance()->Write($self, 3, $szListName);
		if ($szListName eq "Favorite")
		{
			foreach my $szSong ( @{ $self->{pobjFavorite}->get() } )
			{
				$mpszPlaylist{$szSong} = 1;
			}
		}
		else
		{
			foreach my $szSong ( $self->{pobjCharts}->GetChartsList( $szListName ) )
			{
				$mpszPlaylist{$szSong} = 1;
			}
		}
	}
	
	$self->{paszPlaylist} = [];
	push @{ $self->{paszPlaylist} }, keys %mpszPlaylist;
}

########################################################################################################################
sub getCharts
########################################################################################################################
{
	my ($self, $szChartsName) = @_;
	
	return $self->{pobjCharts}->get($szChartsName);
}

########################################################################################################################
sub haveChartsToBeReloaded
########################################################################################################################
{
	my ($self) = @_;
	
	return $self->{pobjCharts}->haveToBeReloaded();
}

########################################################################################################################
sub loadCharts
########################################################################################################################
{
	my ($self, $fDownloadChartsIfNotAvailable) = @_;
	
	return $self->{pobjCharts}->load($fDownloadChartsIfNotAvailable);
}

########################################################################################################################
sub getFavoriteFiles
########################################################################################################################
{
	my ($self) = @_;
	
	return $self->{pobjFavorite}->GetFavoriteFiles();
}

########################################################################################################################
sub addFavorite
########################################################################################################################
{
	my ($self, $szSong) = @_;
	
	return $self->{pobjFavorite}->add($szSong);
}

########################################################################################################################
sub removeFavorite
########################################################################################################################
{
	my ($self, $szSong) = @_;
	
	return $self->{pobjFavorite}->remove($szSong);
}

########################################################################################################################
sub getFavorite
########################################################################################################################
{
	my ($self) = @_;
	
	return $self->{pobjFavorite}->get();
}
1;

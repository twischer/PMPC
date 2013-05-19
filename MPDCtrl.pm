package MPDCtrl;
use strict;
use warnings;
use utf8;
use File::Basename();
use Audio::MPD();
use Glib qw(TRUE FALSE);
# use Inline C => <<'END_C' => Config => LIBS => '-lmpdclient';
# #include <stdio.h>
# #include <stdbool.h>
# #include <string.h>
# #include <ctype.h>
# #include <mpd/client.h>
# 
# 
# peter
# 
# void strlower(char* szDestination, char* szSource);
# 
# 
# int getSongs2(char* szPattern)
# {
# 	int argc = 0;
# 	char argv[][] = { szPattern };
# 	
# 	struct mpd_connection *conn = mpd_connection_new(NULL, 0, 0);
# 	if (conn == NULL) {
# 		fputs("Out of memory\n", stderr);
# 		return 1;
# 	}
# 	
# //	if (mpd_connection_get_error(conn) != MPD_ERROR_SUCCESS)
# //		printErrorAndExit(conn);
# 	
# 	
# 	if (!mpd_send_list_all(conn, ""))
# 	{
# 	//	printErrorAndExit(conn);
# 	}
# 	
# 	
# 	struct mpd_song *song;
# 	while ((song = mpd_recv_song(conn)) != NULL)
# 	{
# //		printf("%s\n", charset_from_utf8(mpd_song_get_uri(song)));
# 
# 		char* szSong = (char*)mpd_song_get_uri(song);
# 		
# 		char szLowerCaseSong[256];
# 		strlower(szLowerCaseSong, szSong);
# 		
# 		bool fMatching = true;
# 		char* szSongPart = (char*)&szLowerCaseSong;
# 		for (int i=1; i<argc; i++)
# 		{
# 			char szSearchWord[256];
# 			strlower(szSearchWord, argv[i]);
# 			
# 			char* szMatchStart = strstr(szSongPart, szSearchWord);
# 			if (szMatchStart == NULL)
# 			{
# 				fMatching = false;
# 				break;
# 			}
# 			else
# 			{
# 				szSongPart = szMatchStart + strlen(szSearchWord);
# 			}
# 		}
# 		
# 		if (fMatching)
# 		{
# 			printf("%s\n", szSong);
# 		}
# 		
# 		mpd_song_free(song);
# 	}
# 	
# //	if (mpd_connection_get_error(conn) != MPD_ERROR_SUCCESS)
# //		printErrorAndExit(conn);
# 	
# 	
# //	if (!mpd_response_finish(conn))
# //		printErrorAndExit(conn);
# 	
# 	
# 	mpd_connection_free(conn);
# 	
# 	return 0;
# }
# 
# 
# void strlower(char* szDestination, char* szSource)
# {
# 	int i = 0;
# 	while (szSource[i] != '\0')
# 	{
# 		szDestination[i] = tolower(szSource[i]);
# 		i++;
# 	}
# 	szDestination[i] = '\0';
# }
# 
#END_C

my $MPDSEARCH = File::Basename::dirname( $0 ) . "/mpdsearch/mpdsearch";
my $MAX_DIFF = 10;

my $m_pobjInstance;

########################################################################################################################
sub GetInstance
########################################################################################################################
{
	my ($proto) = @_;
	
	unless ($m_pobjInstance)
	{
		$m_pobjInstance  = {};
		
		my $class = ref($proto) || $proto;
		bless ($m_pobjInstance, $class);
		
		$m_pobjInstance->StartMPDIfNotRunning();
		
		Logger->GetInstance()->Write($m_pobjInstance, 2, "Starting MPD client ...");
		$m_pobjInstance->{pobjMPD} = new Audio::MPD('CONNTYPE' => $Audio::MPD::REUSE);
		$m_pobjInstance->{nTimeTotal} = 1;
		$m_pobjInstance->{nTimeElapsed} = 0;
		$m_pobjInstance->{fPlaying} = 0;
		$m_pobjInstance->{szSong} = "n/a";
		
		# set needed defaults
		$m_pobjInstance->{pobjMPD}->repeat(0);
		$m_pobjInstance->{pobjMPD}->random(0);
		$m_pobjInstance->{pobjMPD}->fade(4);
		
		if ( (not defined $m_pobjInstance->{pobjMPD}->current) and (not defined $m_pobjInstance->{pobjMPD}->status->time) and ($m_pobjInstance->{pobjMPD}->status->playlistlength() >= 1) )
		{
			Logger->GetInstance()->Write($m_pobjInstance, 2, "Set defined playing status");
			$m_pobjInstance->{pobjMPD}->play(0);
			$m_pobjInstance->{pobjMPD}->pause();
		}
		
		$m_pobjInstance->Update();
	}
	
	return $m_pobjInstance;
}

########################################################################################################################
sub StartMPDIfNotRunning
########################################################################################################################
{
	my ($self) = @_;
	
	my $nMPDPID = `pidof mpd`;
	if ( (not defined $nMPDPID) or ($nMPDPID eq "") )
	{
		Logger->GetInstance()->Write($self, 2, "MPD is not running. It will be started.");
		
		# Todo create .mpd/playlists
		
		my $szConfigFile = File::Spec->rel2abs("./mpd.conf");
		system("mpd \"$szConfigFile\"");
	}
}

########################################################################################################################
sub GetMPD
########################################################################################################################
{
	my ($self) = @_;
	
	return $self->{pobjMPD};
}

########################################################################################################################
sub Update
########################################################################################################################
{
	my ($self) = @_;
	
	if (defined $self->{pobjMPD}->current)
	{
		if ( $self->{pobjMPD}->status->state eq "play" )
		{
			$self->{nTimeElapsed}++;
		}
		else
		{
			# Wiedergabe vorsetzten wenn sie extern gestorppt wurde
			# Pulseaudio probleme minimieren
			if ($self->{fPlaying} == 1)
			{
				$self->{pobjMPD}->play();
			}
		}
		
		my $szNewFile = $self->{pobjMPD}->current->file();
		if ( $self->{szSong} ne $szNewFile )
		{
			if (defined $self->{pobjMPD}->status->time)
			{
				$self->{szSong} = $szNewFile;
				
				$self->{nTimeTotal} = $self->{pobjMPD}->status->time->seconds_total();
				$self->{nTimeElapsed} = $self->{pobjMPD}->status->time->seconds_sofar();
			}
		}
	}
}

########################################################################################################################
sub IsPlaying
########################################################################################################################
{
	my ($self) = @_;
	
	return $self->{fPlaying};
}

########################################################################################################################
sub updateDatabase
########################################################################################################################
{
	my ($self, $szPath) = @_;
	
	Logger->GetInstance()->Write($self, 2, "Updating MPD database ...");
	$self->{pobjMPD}->updatedb($szPath);
	while (defined $self->{pobjMPD}->status->updating_db())
	{
		sleep 1;
	}
}

########################################################################################################################
sub GetElapsedTime
########################################################################################################################
{
	my ($self) = @_;
	
	return $self->{nTimeElapsed};
}

########################################################################################################################
sub GetTotalTime
########################################################################################################################
{
	my ($self) = @_;
	
	return $self->{nTimeTotal};
}

########################################################################################################################
sub GetCurrentSong
########################################################################################################################
{
	my ($self) = @_;
	
	return $self->{szSong};
}

########################################################################################################################
sub Toggle
########################################################################################################################
{
	my ($self) = @_;
	
	# Start playback on first Title
	if ( (defined $self->{pobjMPD}->current) and (defined $self->{pobjMPD}->status->time) )
	{
		# toggle status
		Logger->GetInstance()->Write($self, 2, "Toggle playing status");
		$self->{pobjMPD}->pause();
	}
	elsif ( $m_pobjInstance->{pobjMPD}->status->playlistlength() >= 1 )
	{
		# The playback is broken play the first song of the playlist
		Logger->GetInstance()->Write($self, 2, "Start playback at the beginning");
		$self->{pobjMPD}->play(0);
	}
	
	$self->{fPlaying} = ( $self->{pobjMPD}->status->state eq "play" ) ? 1 : 0;
	
	$self->Update();
}

########################################################################################################################
sub GetSongs
########################################################################################################################
{
	my ($self, $szPattern) = @_;
	
	
	$szPattern = "" unless (defined $szPattern);
	
	
	$szPattern =~ s/\([^\)]*\)//g;
	$szPattern =~ s/\(.*$//g;
	
	$szPattern =~ s/dj|feat|ft|vs|with|present|and|\&|\||\+|\-|\:|\,|\.|\!|\?|\@|\$|\'|\`|\´|\x92|\xB4|\*/ /gi;

	$szPattern =~ s/á|à|â|ã|å/a/gi;
	$szPattern =~ s/é|è|ê|ë/e/gi;
	$szPattern =~ s/í|ì|î|ï/i/gi;
	$szPattern =~ s/ó|ò|ô|õ/o/gi;
	$szPattern =~ s/ú|ù|û/u/gi;
	
#	$szSong =~ s/ae|ä/(ae|ä)/gi;
#	$szSong =~ s/oe|ö/(oe|ö)/gi;
#	$szSong =~ s/ue|ü/(ue|ü)/gi;
	
	$szPattern =~ s/^der|^die|^das|^the//i;

	
	my @aszSongs = ();

	my $szCommand = $MPDSEARCH." ".$szPattern;
	open (my $hMPDSearch, $szCommand." |") or Logger->GetInstance()->Write($self, 0, "Could not open '$szCommand'!");
	
	while (my $szSong = <$hMPDSearch>)
	{
		utf8::decode($szSong);
		chomp($szSong);
		push @aszSongs, $szSong;
	}
	close ($hMPDSearch);
	
	
	return \@aszSongs;
}

########################################################################################################################
sub GetRandomSong
########################################################################################################################
{
	my ($self) = @_;
	
	my $paszSongs = $self->GetSongs();
	
	my $nMusicDirLength = scalar @$paszSongs;
	my $nRand = int( rand($nMusicDirLength) );
	
	return $paszSongs->[$nRand];
}

########################################################################################################################
sub GetMPDDevices
########################################################################################################################
{
	my ($self) = @_;
	
	my @aszDevices = ();
	open( my $hMPC, "mpc outputs |" ) or Logger->GetInstance()->Write($self, 1, "Could not get the MPD device list from mpc!");
	while (my $szLine = <$hMPC>)
	{
		if ($szLine =~ m/\((\w.*)\)/)
		{
			push @aszDevices, $1;
		}
	}
	close( $hMPC );
	
	return @aszDevices;
}

########################################################################################################################
sub SetMPDDevice
########################################################################################################################
{
	my ($self, $szMPDDevice) = @_;
	
	my $niMPDDevice = 0;
	foreach my $szItem ( $self->GetMPDDevices() )
	{
		if ($szItem eq $szMPDDevice)
		{
			$self->{pobjMPD}->output_enable( $niMPDDevice );
		}
		else
		{
			$self->{pobjMPD}->output_disable( $niMPDDevice );
		}
		$niMPDDevice++;
	}
}

1;

package ViewThread;
use strict;
use warnings;
use utf8;
use File::Basename();
use threads();
use Thread::Isolate();
use Glib qw(TRUE FALSE);

chdir(  File::Basename::dirname( $0 )  );
require GUI;
require PMPCConfig;


my @LOCK_BUTTONS = (
	"buttonNext",
	"buttonExit",
#	"buttonMinimize",
	"buttonFavoriteAdd",
	"buttonFavoriteDelete",
	"buttonConfig",
	);

my $MAX_SONG_LENGTH = 120;

my @LIGHTNING_BUTTONS = ("togglebuttonClavilux", "togglebuttonStroboscope");

my $pobjModelThread;
my $fLocked = 0;
my $fUpdateScale = 1;
my $m_nErrorLevel = 0;


########################################################################################################################
sub show
########################################################################################################################
{
	$pobjModelThread = Thread::Isolate->new();
	$pobjModelThread->use("ModelThread");
	
	my $pobjConfig = PMPCConfig->GetInstance();
	$pobjConfig->ConnectSignalForConfigNeedRestart( \&ViewThread::RestartPMPC );
	
	my $fRefresh = modelCall("init", $pobjConfig);
	
	
	my $progressbarInfo = GUI->GetInstance()->GetObject('progressbarInfo');
	$progressbarInfo->{timer} = Glib::Timeout->add(1000, \&update, $progressbarInfo);
	
	
	# MPDCtrl
	$pobjConfig->ConnectSignalForComboBoxList( "szMPDDevice", sub { 
		my @aszMPDDevices = modelCall("getMPDDevices");
		return@aszMPDDevices;
	} );
	
	# Control
	GUI->GetInstance()->ConnectSignal('buttonPlayPause',	'clicked'			=> \&playOrPause);
	connectModelCall('buttonNext', 												"next" );
	GUI->GetInstance()->ConnectSignal( 'buttonRefresh', 'clicked'				=> \&refresh  );
	
	
	# Playlist
	GUI->GetInstance()->ConnectSignal('treeviewTrack',		'row-activated' 	=> sub { playlistAdd(); } );
 	GUI->GetInstance()->ConnectSignal('treeviewPlaylist',	'row-activated' 	=> \&playlistMove);
 	
 	
 	# Favorite
	GUI->GetInstance()->ConnectSignal('buttonFavorite',			'clicked'		=> \&favoriteShow);
	GUI->GetInstance()->ConnectSignal('buttonFavoriteAdd',		'clicked'		=> \&favoriteAdd);
	GUI->GetInstance()->ConnectSignal('buttonFavoriteDelete',	'clicked'		=> \&favoriteRemove);
	
 	$pobjConfig->ConnectSignalForComboBoxList( "szFavoriteFile", sub { 
 		my @aszFavoriteFiles = modelCall("favoriteGetFiles");
 		return @aszFavoriteFiles;
 	} );
	
	
	# Charts
	GUI->GetInstance()->ConnectSignal( 'buttonChartsTop100',	'clicked'			=> sub { chartsShow("Top100"); } );
	GUI->GetInstance()->ConnectSignal( 'buttonChartsDance',		'clicked'			=> sub { chartsShow("Dance"); } );
	GUI->GetInstance()->ConnectSignal( 'buttonChartsUK',		'clicked'			=> sub { chartsShow("UK"); } );
	GUI->GetInstance()->ConnectSignal( 'buttonChartsUS',		'clicked'			=> sub { chartsShow("US"); } );
 	
 	
 	# Search 
	GUI->GetInstance()->ConnectSignal('buttonSearch',		'clicked'			=> \&searchSongs);
	GUI->GetInstance()->ConnectSignal('entrySearch',		'activate'			=> \&searchSongs);
	GUI->GetInstance()->ConnectSignal('buttonShowAll',		'clicked'			=> \&showAllSongs );
	
	
	# LockUnlock
	GUI->GetInstance()->ConnectSignal('buttonLock',			'clicked'			=> \&lockUnlock);
	
	
	# Preview
	GUI->GetInstance()->ConnectSignal('treeviewTrack',		'cursor-changed'		=> \&previewPlay);
	GUI->GetInstance()->ConnectSignal('hscalePreview',		'button-press-event'	=> sub { $fUpdateScale = 0; return FALSE; }  );
	GUI->GetInstance()->ConnectSignal('hscalePreview',		'button-release-event'	=> \&previewChangePosition);
	
	my $fSensitive = PMPCConfig->GetInstance()->GetPreviewActive() ? TRUE : FALSE;
	GUI->GetInstance()->SetSensitive( 'hscalePreview', $fSensitive );
	
	$pobjConfig->ConnectSignalForComboBoxList( "szALSADevicePreview", sub { 
		my @aszPreviewDevices = modelCall("previewGetDevices");
		return @aszPreviewDevices;
	} );
	
	
	# LightningServer
	if (PMPCConfig->GetInstance()->GetLightningActive() == 1)
	{
		foreach my $szButtonName (@LIGHTNING_BUTTONS)
		{
			GUI->GetInstance()->ConnectSignal( $szButtonName, 'clicked'				=> \&lightningSendButtonStats );
			GUI->GetInstance()->SetSensitive( $szButtonName, TRUE );
		}
	}
	
	playlistUpdate();
	updateControls();
	
	refresh() if ($fRefresh);
	
	GUI->GetInstance()->Show( $pobjConfig->GetFullscreen() );
	
	
	modelCall("finit", $m_nErrorLevel);
	
	PMPCConfig->GetInstance()->delete();
	
	#$pobjModelThread->kill();
	threads->object( $pobjModelThread->tid )->kill("KILL");
	
	return $m_nErrorLevel
}

########################################################################################################################
sub modelCall
########################################################################################################################
{
	my ($szFunction, @aszArgs) = @_;
	
	
	$szFunction = "ModelThread::".$szFunction;
	
	my @aszRetValues = ();
	my $szRetValue;
	if (wantarray())
	{
		@aszRetValues = $pobjModelThread->call( $szFunction, @aszArgs );
	}
	else
	{
		$szRetValue = $pobjModelThread->call( $szFunction, @aszArgs );
	}
	
	die( $pobjModelThread->err ) if $pobjModelThread->err;
	
	
	return wantarray() ? @aszRetValues : $szRetValue;
}

########################################################################################################################
sub modelDetachedCall
########################################################################################################################
{
	my ($szFunction, $pDoneFunction, @aszArgs) = @_;
	
	my $pobjJob = $pobjModelThread->call_detached( "ModelThread::".$szFunction, @aszArgs );
	die( $pobjModelThread->err ) if $pobjModelThread->err;
	
	GUI->GetInstance()->DoHeavyWork(1, sub
	{
		if ($pobjJob->is_finished())
		{
			my @aszRetValues = $pobjJob->returned;
			&$pDoneFunction( @aszRetValues );
			return FALSE;
		}
		else
		{
			return TRUE;
		}
	}, undef );
}

########################################################################################################################
sub connectModelCall
########################################################################################################################
{
	my ($szName, $szFunction) = @_;
	
	GUI->GetInstance()->ConnectSignal( $szName, 'clicked' => sub { modelCall($szFunction); }  );
}

########################################################################################################################
sub RestartPMPC
########################################################################################################################
{
	Logger->GetInstance()->Write( undef, 2, "Restarting because of new config ...");
	
	Gtk2->main_quit();
	$m_nErrorLevel = 1;
}

########################################################################################################################
sub playOrPause
########################################################################################################################
{
	modelCall("playOrPause");
	updateControls();
}

########################################################################################################################
sub refresh
########################################################################################################################
{
	GUI->GetInstance()->SetSensitive( 'buttonRefresh', FALSE );
	
	my $nResponse = GUI->GetInstance()->ShowDialog("messagedialogDownloadCharts");
	my $fDownloadChartsIfNotAvailable = ($nResponse eq "yes") ? 1 : 0;
	
	
	modelDetachedCall("refresh", sub
 	{
 		GUI->GetInstance()->SetSensitive( 'buttonRefresh', TRUE );
 	}, $fDownloadChartsIfNotAvailable );
}

########################################################################################################################
sub playlistAdd
########################################################################################################################
{
	my ($szSong) = @_; 
	
	
	unless (defined $szSong)
	{
		$szSong = GUI->GetInstance()->GetSelItemOfTrackTree();
	}
	
	my $szMsgBox = modelCall("playlistAdd", $szSong);
	if ($szMsgBox eq "PLAYLIST_FULL")
	{
		GUI->GetInstance()->ShowInfoDialog( "Playliste ist voll", 
 			"Bitte warten sie bis ein Song gespielt wurde und fügen sie ihn dann hinzu." );
	}
	elsif ($szMsgBox eq "PLAYLIST_EXISTS")
	{
		GUI->GetInstance()->ShowInfoDialog( "Titel schon in der Playliste", 
			"Der von ihnen gewünschte Title befindet sich schon in der Playlist und wird in Kürze gespielt." );
	}
	elsif ($szMsgBox eq "PLAYLIST_SONG_NOT_EXISTS")
	{
		my $nResponse = GUI->GetInstance()->ShowDialog("messagedialogDownloadQuestion");
		if ($nResponse eq "yes")
		{
			my $nID = GUI->GetInstance()->GetSelItemOfTrackTree(0);
			
			modelDetachedCall("downloadSong", sub
		 	{
		 		playlistAdd( $szSong );
		 	}, $szSong, $nID );
		}
	}
	
	playlistUpdate();
	GUI->GetInstance()->SetCursorToEndOfPlaylistTree();
}

########################################################################################################################
sub playlistMove
########################################################################################################################
{
 	my ($treepath) = GUI->GetInstance()->GetObject('treeviewPlaylist')->get_cursor();
 	my $nPos = $treepath->get_indices();

	modelCall("playlistMove", $nPos);
	
	playlistUpdate();
}

########################################################################################################################
sub showAllSongs
########################################################################################################################
{
	searchSongs(1);
}

########################################################################################################################
sub searchSongs
########################################################################################################################
{
	my ($fShowAll) = @_; 
	
	
	my $szSearchString = GUI->GetInstance()->GetText('entrySearch');
	$szSearchString = "" if ( (defined $fShowAll) and ($fShowAll == 1) );
	
 	modelDetachedCall("searchSongs", sub
 	{
 		my ($paszSongs) = @_;
 		
 		GUI->GetInstance()->WriteTrackTree( $paszSongs );
 		
 	}, $szSearchString );
}

########################################################################################################################
sub lockUnlock
########################################################################################################################
{
	if ($fLocked == 1)
	{
		GUI->GetInstance()->SetText('entryPassword', "");
		
		my $nResponse = GUI->GetInstance()->ShowDialog( "dialogPassword" );
		if ( $nResponse == 1 )
		{
			my $szPassword = PMPCConfig->GetInstance()->GetPassword();
			if ( GUI->GetInstance()->GetText('entryPassword') eq $szPassword )
			{
				$fLocked = 0;
				
				Logger->GetInstance()->Write(undef, 2, "Player unlocked");
			}
			else
			{
				Logger->GetInstance()->Write(undef, 2, "Player not unlocked. Wrong password entered");
			}
		}
	}
	else
	{
		$fLocked = 1;
		Logger->GetInstance()->Write(undef, 2, "Player locked");
	}
	
	
	my $fSensetive = $fLocked ? FALSE : TRUE;
	foreach (@LOCK_BUTTONS)
	{
		GUI->GetInstance()->SetSensitive( $_, $fSensetive );
	}
	
	# Playlist nur sperren, wenn es konfiguriert wurde
	if ( PMPCConfig->GetInstance()->GetLockPlaylist() )
	{
		GUI->GetInstance()->SetSensitive( "treeviewPlaylist", $fSensetive );
	}
	
	my $szLockButtonText = $fLocked ? "Entsperren" : "Sperren";
	GUI->GetInstance()->SetLabel( 'buttonLock', $szLockButtonText );
}

########################################################################################################################
sub previewPlay
########################################################################################################################
{
	my $szSong = GUI->GetInstance()->GetSelItemOfTrackTree();
	
	my $szShortSong = getShortSong( $szSong );
 	GUI->GetInstance()->SetText('labelPreview', $szShortSong);
 	
 	my $nDuration = modelCall("previewPlay", $szSong);
	my $hscalePreview = GUI->GetInstance()->GetObject('hscalePreview');
	$hscalePreview->set_range( 0, $nDuration + 10 );
}

########################################################################################################################
sub previewChangePosition
########################################################################################################################
{
	my $adjustmentPreview = GUI->GetInstance()->GetObject("adjustmentPreview");
	my $nNewPosTime = $adjustmentPreview->get_value();
 	
	modelCall("previewChangePosition", $nNewPosTime);
	$fUpdateScale = 1;
 	
	update();
 	
 	return FALSE;
}

########################################################################################################################
sub lightningSendButtonStats
########################################################################################################################
{
	my @afState = ();
	foreach my $szButtonName (@LIGHTNING_BUTTONS)
	{
		push @afState, GUI->GetInstance()->GetObject( $szButtonName )->get_active() == 1 ? 1 : 0;
	}
	
	modelCall("lightningSendButtonStats", @afState);
}

########################################################################################################################
sub chartsShow
########################################################################################################################
{
	my ($szChartsName) = @_;
	
	
	my $paszCharts = modelCall("chartsGet", $szChartsName);
	GUI->GetInstance()->WriteTrackTree( $paszCharts );
}

########################################################################################################################
sub favoriteShow
########################################################################################################################
{
	my $paszFavorites = modelCall("favoriteGet");
	GUI->GetInstance()->WriteTrackTree( $paszFavorites );
}

########################################################################################################################
sub favoriteAdd
########################################################################################################################
{
	my $szSong = GUI->GetInstance()->GetSelItemOfTrackTree();
	my $szResult = modelCall("favoriteAdd", $szSong);
	
	if ($szResult eq "FAVORITE_NO_SONG_SELECTED")
	{
		GUI->GetInstance()->ShowInfoDialog( "Kein Titel ausgewählt", 
			"Bitte wählen sie erst einen Titel aus der zu den Favoriten hinzugefügt werden soll.");
	}
	elsif ($szResult eq "FAVORITE_SONG_ALREADY_IN_LIST")
	{
		GUI->GetInstance()->ShowInfoDialog( "Titel schon vorhanden", "Der ausgewählte Titel ist in den Favoriten schon vorhanden.");
	}
}

########################################################################################################################
sub favoriteRemove
########################################################################################################################
{
	my $szSong = GUI->GetInstance()->GetSelItemOfTrackTree();
	my $szResult = modelCall("favoriteRemove", $szSong);
	
	if ($szResult eq "FAVORITE_NO_SONG_SELECTED")
	{
		GUI->GetInstance()->ShowInfoDialog( "Kein Titel ausgewählt", 
			"Bitte wählen sie erst einen Titel aus der aus den Favoriten gelöscht werden soll.");
	}
	else
	{
		favoriteShow();
	}
}



########################################################################################################################
sub update
########################################################################################################################
{
	my $fUpdatePlaylist = modelCall("update");
	if ($fUpdatePlaylist)
	{
		playlistUpdate();
	}
	
	updateControls();
	
	# Preview
	if ($fUpdateScale == 1)
	{
		my $nPosTime = modelCall("previewGetPosition");
		my $adjustmentPreview = GUI->GetInstance()->GetObject('adjustmentPreview');
		$adjustmentPreview->set_value( $nPosTime );
	}
	
	return TRUE;
}

########################################################################################################################
sub playlistUpdate
########################################################################################################################
{
 	my $liststorePlaylist = GUI->GetInstance()->GetObject('liststorePlaylist');
 	$liststorePlaylist->clear();
	
	foreach my $szSong ( modelCall("playlistGet") )
	{
			$liststorePlaylist->set( $liststorePlaylist->append, 0 => $szSong );
	}
}

########################################################################################################################
sub updateControls
########################################################################################################################
{
	my ($szSong, $dFraction, $szTimeInfo, $fIsPlaying) = modelCall("getInfo");
	
	
	my $szShortSong = getShortSong( $szSong );
	GUI->GetInstance()->SetText( 'labelInfo', $szShortSong );

	my $progressbarInfo = GUI->GetInstance()->GetObject('progressbarInfo');
	$progressbarInfo->set_fraction( $dFraction );
	$progressbarInfo->set_text( $szTimeInfo );
	
	my $szButtonText = $fIsPlaying ? "gtk-media-pause" : "gtk-media-play";
 	GUI->GetInstance()->SetLabel( 'buttonPlayPause', $szButtonText );
}


########################################################################################################################
sub getShortSong
########################################################################################################################
{
	my ($szSong) = @_;
	
	
	# Song namen beschneiden wenn zu lang für die GUI
	my $nSongLength = length( $szSong );
	
	my $szShortSong = $szSong;
	if ($nSongLength > $MAX_SONG_LENGTH)
	{
		$szShortSong = "..." . substr( $szSong , $nSongLength - $MAX_SONG_LENGTH );
	}
	
	return $szShortSong;
}

1;

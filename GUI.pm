package GUI;
use strict;
use warnings;
use utf8;
use Gtk2();
use Glib qw(TRUE FALSE);
use Memoize();
use File::stat();
use POSIX();
#use threads();
#use Thread::Queue();
#Gtk2::Gdk::Threads->init();
Gtk2->init();
#Glib::Object->set_threadsafe(TRUE);

require Logger;

my $m_pobjInstance;

# Save the return values of this function (speed up)
Memoize::memoize('GUI::GetDateOfFile');



########################################################################################################################
sub GetInstance
########################################################################################################################
{
	my ($proto) = @_;
	
	unless ($m_pobjInstance)
	{
		my $class = ref($proto) || $proto;
		$m_pobjInstance = bless ( {}, $class );
		
		Logger->GetInstance()->Write($m_pobjInstance, 2, "Loading GUI elements ...");
		
		$m_pobjInstance->{pobjBuilder} = Gtk2::Builder->new();
		$m_pobjInstance->{pobjBuilder}->add_from_file('gui.glade');
		
		$m_pobjInstance->{pobjListstoreTrack} = $m_pobjInstance->GetObject('treeviewTrack')->get_model();
		
		$m_pobjInstance->ConnectSignal( 'windowMain', 'size-request' => sub { $m_pobjInstance->WindowSizeChanged(); } );
		$m_pobjInstance->ConnectSignal( 'buttonExit', 'clicked' => sub { Gtk2->main_quit(); } );
		$m_pobjInstance->ConnectSignal( 'buttonMinimize', 'clicked' => sub { $m_pobjInstance->Minimize(); } );
	}
	
	return $m_pobjInstance;
}

########################################################################################################################
sub WindowSizeChanged
########################################################################################################################
{
	my ($self) = @_;
	
	if (defined $self->{pobjBuilder})
	{
		my ($nWidth, $nHeight) = $self->GetObject('windowMain')->get_size();
		
		my $vpanedTreeviews = $self->GetObject('vpanedTreeviews');
		$vpanedTreeviews->set_size_request($nWidth - 160, $nHeight - 190);
	}
}

########################################################################################################################
sub Minimize
########################################################################################################################
{
	my ($self) = @_;
	
	$self->GetObject( 'windowMain' )->set_functions('GDK_FUNC_MINIMIZE');
}

########################################################################################################################
sub Show
########################################################################################################################
{
	my ($self, $fFullscreen) = @_;

	$fFullscreen = 0 unless(defined $fFullscreen);
	
	my $pobjWindow = $self->GetObject( 'windowMain' );

	
	if ($fFullscreen == 1)
	{
		$pobjWindow->fullscreen();
#		$pobjWindow->set_keep_above(TRUE);
	}
	
	$pobjWindow->show();
	
	Gtk2->main();
	
	$pobjWindow->hide();
}

########################################################################################################################
sub Refresh
########################################################################################################################
{
	my ($self) = @_;

	Gtk2->main_iteration_do(FALSE);
}

########################################################################################################################
sub ConnectSignal
########################################################################################################################
{
	my ($self, $szName, $szSignal, $pFuncion) = @_;
	
	$self->GetObject( $szName )->signal_connect( $szSignal => $pFuncion );
}

########################################################################################################################
sub SetLabel
########################################################################################################################
{
	my ($self, $szName, $szLabel) = @_;
	
	$self->GetObject( $szName )->set_label( $szLabel );
}

########################################################################################################################
sub SetText
########################################################################################################################
{
	my ($self, $szName, $szText) = @_;
	
	$self->GetObject( $szName )->set_text( $szText );
}

########################################################################################################################
sub GetText
########################################################################################################################
{
	my ($self, $szName) = @_;
	
	return $self->GetObject( $szName )->get_text();
}

########################################################################################################################
sub SetSensitive
########################################################################################################################
{
	my ($self, $szName, $fSensitive) = @_;
	
	$self->GetObject( $szName )->set_sensitive( $fSensitive );
}

########################################################################################################################
sub GetObject
########################################################################################################################
{
	my ($self, $szName) = @_;
	
	
	my $pobj = $self->{pobjBuilder}->get_object( $szName );
	
	unless (defined $pobj)
	{
		Logger->GetInstance()->Write( $self, 0, "The Object with the name '$szName' is not defined in the GUI!" );
	}
	
	return $pobj;
}

########################################################################################################################
sub GetSelItemOfTrackTree
########################################################################################################################
{
	my ($self, $nColumnID) = @_;
	
	$nColumnID = 1 unless (defined $nColumnID);
	
	my $treeviewTrack = $self->GetObject( 'treeviewTrack' );
	my ($treepath) = $treeviewTrack->get_cursor();
	
	my $szFileName = "";
	if (defined $treepath)
	{
		my $liststore = $treeviewTrack->get_model();
		my $treeiter = $liststore->get_iter( $treepath );
		$szFileName = $liststore->get( $treeiter, $nColumnID );
	}
	
	return $szFileName;
}

########################################################################################################################
sub GetDateOfFile
########################################################################################################################
{
	my ($self, $szFile) = @_;
	
	if (defined $szFile)
	{
		my $pobjFileStat = File::stat::stat( PMPCConfig->GetInstance()->GetMusicDir() . "/" . $szFile );
		if (defined $pobjFileStat)
		{
			my $nFileTime = $pobjFileStat->mtime();
			return POSIX::strftime( "%Y-%02m-%02e %H:%M:%S ", localtime($nFileTime) );
		}
		else
		{
			return "n/a";
		}
	}
	else
	{
		return "n/a";
	}
}

########################################################################################################################
sub ClearTrackTree
########################################################################################################################
{
	my ($self) = @_;
	
	$self->{pobjListstoreTrack}->clear();
}

########################################################################################################################
sub WriteTrackTree
########################################################################################################################
{
	my ($self, $pobjList) = @_;
	
	$self->ClearTrackTree();
	
	my $szListType = ref($pobjList);
	if ( $szListType eq "ARRAY" )
	{
		foreach my $szSong ( @$pobjList )
		{
			my $nPosition = 0;
			if (ref($szSong) eq "ARRAY")
			{
				($szSong, $nPosition) = @$szSong;
			}
			
			$self->AddToTrackTree( $szSong, $nPosition );
		}
	}
	elsif ( $szListType eq "HASH" )
	{
		foreach my $szSong ( keys %$pobjList )
		{
			$self->AddToTrackTree( $szSong, $pobjList->{$szSong} );
		}
	}
	else
	{
		Logger->GetInstance()->Write( $self, 0, "The type of the list is unkown (type: $szListType, list: $pobjList)" );
	}
}

########################################################################################################################
sub AddToTrackTree
########################################################################################################################
{
	my ($self, $szSong, $nPosition) = @_;
	
	$nPosition = 0 unless (defined $nPosition);
	
	my $szDate = $self->GetDateOfFile( $szSong );
	$self->{pobjListstoreTrack}->set( $self->{pobjListstoreTrack}->append, 
		0 => $nPosition, 1 => $szSong, 2 => $szDate );
}

########################################################################################################################
sub SetCursorToEndOfPlaylistTree
########################################################################################################################
{
	my ($self) = @_;
	
	my $treeviewPlaylist = $self->GetObject('treeviewPlaylist');
	my $liststorePlaylist = $treeviewPlaylist->get_model();
	
	my $pobjIter = $liststorePlaylist->get_iter_first();
	while (  defined $liststorePlaylist->iter_next( $pobjIter )  )
	{
		$pobjIter = $liststorePlaylist->iter_next( $pobjIter );
	}
	
	my $treepath = $liststorePlaylist->get_path( $pobjIter );
	$treeviewPlaylist->set_cursor( $treepath );
}

########################################################################################################################
sub ShowDialog
########################################################################################################################
{
	my ($self, $szDialogName, $szText1, $szText2) = @_;
	
	my $pobjDialog = $self->GetObject( $szDialogName );
	
	if (defined $szText1)
	{
		$pobjDialog->set_property( "text", $szText1 );
	}
	
	if (defined $szText2)
	{
		$pobjDialog->set_property( "secondary-text", $szText2 );
	}
	
	my $nResponse = $pobjDialog->run();
	$pobjDialog->hide();
	
	return $nResponse;
}

########################################################################################################################
sub ShowInfoDialog
########################################################################################################################
{
	my ($self, $szText1, $szText2) = @_;
	
	$self->ShowDialog( "messagedialogInfo", $szText1, $szText2 );
}

########################################################################################################################
sub DoHeavyWork
########################################################################################################################
{
	my ($self, $fShowWorkingDialog, @apFunctions) = @_;


	my $pAbortFunction = pop @apFunctions;
	
	my $pobjDialog = $self->GetObject("messagedialogLoading");
	if ($fShowWorkingDialog == 1)
	{
		push @apFunctions, sub
		{
			$pobjDialog->response(1);
			$pobjDialog->hide();
			
			Logger->GetInstance()->Write( $self, 3, "Done." );
			return FALSE;
		};
	}
	
	
	my $pobjSource = Glib::Idle->add( sub
	{
		my $pFunction = $apFunctions[0];
		my $fReturn = &$pFunction();
		
		if ($fReturn == FALSE)
		{
			shift @apFunctions;
			$fReturn = TRUE if (@apFunctions >= 1);
		}
		return $fReturn;
	} );
	
	
	if ($fShowWorkingDialog == 1)
	{
		my $nResponse = $pobjDialog->run();
		$pobjDialog->hide();
		
		if ($nResponse eq "cancel")
		{
			Glib::Source->remove( $pobjSource );
			&$pAbortFunction() if (defined $pAbortFunction);
			
			Logger->GetInstance()->Write( $self, 3, "Aborted." );
		}
	}
}

1;

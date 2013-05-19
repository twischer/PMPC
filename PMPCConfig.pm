package PMPCConfig;
use strict;
use warnings;
use utf8;
use Storable();
require Logger;

my $CONFIG_FILE = "config.dat";

my %m_mpszConfigToDialog = (
	'fUseMusicArchive'		=> [ "radiobuttonUseMusicArchive", 1 ],
	'fUseCharts'			=> [ "radiobuttonUseCharts", 1 ],
	'fUseTop100'			=> [ "checkbuttonUseTop100Charts", 1 ],
	'fUseDance'				=> [ "checkbuttonUseDanceCharts", 1 ],
	'fUseUK'				=> [ "checkbuttonUseUKCharts", 1 ],
	'fUseUS'				=> [ "checkbuttonUseUSCharts", 1 ],
	'fUseFavorite'			=> [ "checkbuttonUseFavorite", 1 ],
	'fPreviewActive'		=> [ "checkbuttonPreviewActive", 1 ],
	'fLockPlaylist'			=> [ "checkbuttonLockPlaylist", 0 ],
	'fLightningActive'		=> [ "checkbuttonLightningActive", 1 ],
	'fDownloadSong'			=> [ "checkbuttonDownloadSongs", 0 ],
	'fFullscreen'			=> [ "checkbuttonFullscreen", 1 ],
	'nMaxPlaylistLength'	=> [ "adjustmentMaxPlaylistLength", 0 ],
	'nLightningPort'		=> [ "adjustmentLightningPort", 1 ],
	'szURLTop100'			=> [ "entryURLTop100", 1 ],
	'szURLDance'			=> [ "entryURLDance", 1 ],
	'szURLUK'				=> [ "entryURLUK", 1 ],
	'szURLUS'				=> [ "entryURLUS", 1 ],
	'szChartsFile'			=> [ "entryChartsFile", 1 ],
	'szPassword'			=> [ "entryConfigPassword", 0 ],
	'szFavoriteFile'		=> [ "comboboxFavoriteFile", 1 ],
	'szALSADevicePreview'	=> [ "comboboxPreviewDevice", 1 ],
	'szMPDDevice'			=> [ "comboboxMPDDevice", 1 ],
	'szMusicDir'			=> [ "filechooserbuttonMusicDir", 1 ],
	);

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
		
 		GUI->GetInstance()->ConnectSignal( 'buttonConfig', 'clicked' => sub { $m_pobjInstance->ShowDialog(); }  );
		$m_pobjInstance->LoadConfig();
	}
	
	return $m_pobjInstance;
}

########################################################################################################################
sub delete
########################################################################################################################
{
	my ($self) = @_;
}

########################################################################################################################
sub LoadConfig
########################################################################################################################
{
	my ($self) = @_;
	
	$self->{szConfigDir} = $ENV{'HOME'} . "/." . File::Basename::basename( $0 ) . "/";
	unless ( -d $self->{szConfigDir} )
	{
		mkdir $self->{szConfigDir} or Logger->GetInstance()->Write($self, 0, "Could not create directory '".$self->{szConfigDir}."': $!");
	}
	
	if ( -f $self->{szConfigDir}.$CONFIG_FILE )
	{
		$self->{pmpszConfig} = Storable::retrieve( $self->{szConfigDir}.$CONFIG_FILE );
		
		$self->{fIsNewConfig} = 0;
	}
	else
	{
		$self->{pmpszConfig} = {
			'fPreviewActive'		=> 0,
			'fLockPlaylist'			=> 1,
			'fUseMusicArchive'		=> 1,
			'fLightningActive'		=> 0,
			'nMaxPlaylistLength'	=> 20,
			'nLightningPort'		=> 80056,
			'szMusicDir'			=> $ENV{'HOME'}."/Musik",
			'szFavoriteFile'		=> "favorite.dat",
			'szChartsFile'			=> "charts.dat",
			'szPassword'			=> "party",
			'szALSADevicePreview'	=> "Default Gstreamer Device",
			'szMPDDevice'			=> "My ALSA Device",
			'szURLTop100'			=> "http://www.mtv.de/charts/germany",
			'szURLDance'			=> "http://www.mtv.de/charts/dance",
			'szURLUK'				=> "http://www.mtv.de/charts/UK",
			'szURLUS'				=> "http://www.mtv.de/charts/us",
			};
		
		$self->{fIsNewConfig} = 1;
	}
}

########################################################################################################################
sub SaveNewConfig
########################################################################################################################
{
	my ($self) = @_;
	
	Storable::store( $self->{pmpszNewConfig}, $self->{szConfigDir}.$CONFIG_FILE );
}

########################################################################################################################
sub ShowDialog
########################################################################################################################
{
	my ($self) = @_;
	
	$self->SetConfigToDialog();
	
	my $nResponse = GUI->GetInstance()->ShowDialog('dialogConfig');

	if ($nResponse == 1)
	{
		my $fConfigNeedRestart = $self->GetConfigFromDialog();
		$self->SaveNewConfig();
		$self->{fIsNewConfig} = 0;
		
		my $pfConfigNeedRestart = $self->{pfConfigNeedRestart};
		if ( (defined $pfConfigNeedRestart) and ($fConfigNeedRestart) )
		{
			&$pfConfigNeedRestart();
		}
	}
}

########################################################################################################################
sub ShowDialogIfConfigNew
########################################################################################################################
{
	my ($self) = @_;
	
	if ( $self->{fIsNewConfig} == 1 )
	{
		$self->ShowDialog();
	}
}

########################################################################################################################
sub SetConfigToDialog
########################################################################################################################
{
	my ($self) = @_;
	
	foreach my $szValueName (keys %m_mpszConfigToDialog)
	{
		my $szValue = $self->{pmpszConfig}->{$szValueName};
		
		my $pobjWidget = GUI->GetInstance()->GetObject( $m_mpszConfigToDialog{$szValueName}->[0] );
		my $szWidgetType = ref( $pobjWidget );
		
		if ($szWidgetType eq "Gtk2::Entry")
		{
			$pobjWidget->set_text( $szValue );
		}
		elsif ( ($szWidgetType eq "Gtk2::CheckButton") or ($szWidgetType eq "Gtk2::RadioButton") )
		{
			$pobjWidget->set_active( $szValue );
		}
		elsif ($szWidgetType eq "Gtk2::ComboBox")
		{
			$pobjWidget->get_model()->clear();
			
			my $pfGetList = $self->{pmpfGetList}->{$szValueName};
			if (defined $pfGetList)
			{
				my $niItem = 0;
				foreach my $szItem ( &$pfGetList() )
				{
					$pobjWidget->append_text( $szItem );
					
					if ($szItem eq $szValue)
					{
						$pobjWidget->set_active( $niItem );
					}
					$niItem++;
				}
			}
			else
			{
				Logger->GetInstance()->Write($self, 1, "Pointer to the GetList function for '$szValueName' is not set.");
			}
		}
		elsif ($szWidgetType eq "Gtk2::FileChooserButton")
		{
			$pobjWidget->set_current_folder( $szValue );
		}
		elsif ($szWidgetType eq "Gtk2::Adjustment")
		{
			$pobjWidget->set_value( $szValue );
		}
		else
		{
			Logger->GetInstance()->Write($self, 1, "Widget type '$szWidgetType' for '$szValueName' is unkown.");
		}
	}
}

########################################################################################################################
sub GetConfigFromDialog
########################################################################################################################
{
	my ($self) = @_;
	
	my $fConfigNeedRestart = 0;
	foreach my $szValueName (keys %m_mpszConfigToDialog)
	{
		my $szValue = "";
		
		my $pobjWidget = GUI->GetInstance()->GetObject( $m_mpszConfigToDialog{$szValueName}->[0] );
		my $szWidgetType = ref( $pobjWidget );
		
		if ($szWidgetType eq "Gtk2::Entry")
		{
			$szValue = $pobjWidget->get_text();
		}
		elsif ( ($szWidgetType eq "Gtk2::CheckButton") or ($szWidgetType eq "Gtk2::RadioButton") )
		{
			$szValue = ( $pobjWidget->get_active() == 1 ) ? 1 : 0;
		}
		elsif ($szWidgetType eq "Gtk2::ComboBox")
		{
			$szValue = $pobjWidget->get_active_text();
		}
		elsif ($szWidgetType eq "Gtk2::FileChooserButton")
		{
			$szValue = $pobjWidget->get_current_folder();
		}
		elsif ($szWidgetType eq "Gtk2::Adjustment")
		{
			$szValue = $pobjWidget->get_value();
		}
		else
		{
			Logger->GetInstance()->Write($self, 1, "Widget type '$szWidgetType' for '$szValueName' is unkown.");
		}
		
		
		if ( (defined $szValue) and ($szValue ne "") )
		{
			my $fNeedRestart = $m_mpszConfigToDialog{$szValueName}->[1];
			if ($fNeedRestart == 0)
			{
				$self->{pmpszConfig}->{$szValueName} = $szValue;
			}
			$self->{pmpszNewConfig}->{$szValueName} = $szValue;
			
			
			if (  ($fNeedRestart == 1) and ( (not exists $self->{pmpszConfig}->{$szValueName}) or ($self->{pmpszConfig}->{$szValueName} ne $szValue) )  )
			{
				$fConfigNeedRestart = 1;
			}
		}
		else
		{
			Logger->GetInstance()->Write($self, 1, "Value for '$szValueName' was not saved.");
		}
	}
	
	return $fConfigNeedRestart;
}

########################################################################################################################
sub ConnectSignalForComboBoxList
########################################################################################################################
{
	my ($self, $szValueName, $pfGetList) = @_;
	
	$self->{pmpfGetList}->{$szValueName} = $pfGetList;
}

########################################################################################################################
sub ConnectSignalForConfigNeedRestart
########################################################################################################################
{
	my ($self, $pfConfigNeedRestart) = @_;
	
	$self->{pfConfigNeedRestart} = $pfConfigNeedRestart;
}

########################################################################################################################
sub GetMusicDir
########################################################################################################################
{
	my ($self) = @_;
	
	return $self->{pmpszConfig}->{szMusicDir}; 
}

########################################################################################################################
sub GetFavoriteFile
########################################################################################################################
{
	my ($self) = @_;
	
	return $self->{szConfigDir} . $self->{pmpszConfig}->{szFavoriteFile}; 
}

########################################################################################################################
sub GetChartsFile
########################################################################################################################
{
	my ($self) = @_;
	
	return $self->{szConfigDir} . $self->{pmpszConfig}->{szChartsFile}; 
}

########################################################################################################################
sub GetConfigDir
########################################################################################################################
{
	my ($self) = @_;
	
	return $self->{szConfigDir};
}
########################################################################################################################
sub GetPassword
########################################################################################################################
{
	my ($self) = @_;
	
	return $self->{pmpszConfig}->{szPassword}; 
}

########################################################################################################################
sub GetALSADevicePreview
########################################################################################################################
{
	my ($self) = @_;
	
	return $self->{pmpszConfig}->{szALSADevicePreview}; 
}

########################################################################################################################
sub GetMPDDevice
########################################################################################################################
{
	my ($self) = @_;
	
	return $self->{pmpszConfig}->{szMPDDevice}; 
}

########################################################################################################################
sub GetPreviewActive
########################################################################################################################
{
	my ($self) = @_;
	
	return $self->{pmpszConfig}->{fPreviewActive}; 
}

########################################################################################################################
sub GetDownloadSong
########################################################################################################################
{
	my ($self) = @_;
	
	return $self->{pmpszConfig}->{fDownloadSong}; 
}

########################################################################################################################
sub GetLockPlaylist
########################################################################################################################
{
	my ($self) = @_;
	
	return $self->{pmpszConfig}->{fLockPlaylist}; 
}

########################################################################################################################
sub GetUseCharts
########################################################################################################################
{
	my ($self) = @_;
	
	return $self->{pmpszConfig}->{fUseCharts}; 
}

########################################################################################################################
sub GetChartsLists
########################################################################################################################
{
	my ($self) = @_;
	
	my @aszChartsLists = ();
	foreach my $szChartsList ( "Top100", "Dance", "UK", "US", "Favorite" )
	{
		my $szValueName = "fUse" . $szChartsList;
		if ($self->{pmpszConfig}->{$szValueName} == 1)
		{
			push @aszChartsLists, $szChartsList;
		}
	}
	
	return @aszChartsLists;
}

########################################################################################################################
sub GetMaxPlaylistLength
########################################################################################################################
{
	my ($self) = @_;
	
	return $self->{pmpszConfig}->{nMaxPlaylistLength}; 
}

########################################################################################################################
sub GetLightningActive
########################################################################################################################
{
	my ($self) = @_;
	
	return $self->{pmpszConfig}->{fLightningActive}; 
}

########################################################################################################################
sub GetLightningPort
########################################################################################################################
{
	my ($self) = @_;
	
	return $self->{pmpszConfig}->{nLightningPort}; 
}

########################################################################################################################
sub GetChartsURL
########################################################################################################################
{
	my ($self, $szChartsName) = @_;
	
	my $szValueName = "szURL" . $szChartsName;
	return $self->{pmpszConfig}->{$szValueName}; 
}

########################################################################################################################
sub GetFullscreen
########################################################################################################################
{
	my ($self) = @_;
	
	return $self->{pmpszConfig}->{fFullscreen}; 
}

1;

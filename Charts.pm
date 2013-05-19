package Charts;
use strict;
use warnings;
use utf8;
use Time::Local();
use Net::Ping();
use LWP::UserAgent();
use HTML::TokeParser();
use Storable();
require Logger;
require MPDCtrl;
require GrooveSharkDownloader;

########################################################################################################################
sub new
########################################################################################################################
{
	my ($proto, $pobjConfig) = @_;
	
	my $self  = {};
		
	my $class = ref($proto) || $proto;
	bless ($self, $class);
	
	$self->{pobjConfig} = $pobjConfig;
	$self->{pmpszCharts} = {};
	$self->{paszNotFoundSongs} = [];
	
	my $szChartsFile = $pobjConfig->GetChartsFile();
	if ( -f $szChartsFile )
	{
		$self->{pmpszCharts} = Storable::retrieve( $szChartsFile );
	}
	
	return $self;
}

########################################################################################################################
sub delete
########################################################################################################################
{
	my ($self) = @_;
	
	my $szChartsFile = $self->{pobjConfig}->GetChartsFile();
	Storable::store( $self->{pmpszCharts}, $szChartsFile );
}

########################################################################################################################
sub haveToBeReloaded
########################################################################################################################
{
	my ($self) = @_;
	
	
	my $fReload = 0;
	if (defined $self->{pmpszCharts}->{nTimeStamp})
	{
		my (undef, undef, undef, $nDay, $nMonth, $nYear) = localtime( time() );
		
		my $nLastFridayTime = Time::Local::timelocal( 0, 0, 0, $nDay, $nMonth, $nYear );
		until ( $self->IsItFriday( $nLastFridayTime ) )	# Look for Friday
		{
			$nLastFridayTime -= 24 * 60 * 60;	# subtract one day
		}
		
		my $nOldTime = $self->{pmpszCharts}->{nTimeStamp};
		if ( $nLastFridayTime > $nOldTime )
		{
			$fReload = 1;
		}
	}
	else
	{
		$fReload = 1;
	}
	
	return $fReload;
}

########################################################################################################################
sub IsItFriday
########################################################################################################################
{
	my ($self, $nTimeStamp) = @_;
	
	my @aszTime = localtime( $nTimeStamp );
	
	return ($aszTime[6] == 5);
}

########################################################################################################################
sub load
########################################################################################################################
{
	my ($self, $fDownloadChartsIfNotAvailable) = @_;
	
	
	my $szPingCommand = "ping -c1 www.mtv.de";
	Logger->GetInstance()->Write($self, 2, "Executing ping command '$szPingCommand ' ...");
	my $szPingLines = `$szPingCommand 2>&1`;
	Logger->GetInstance()->Write($self, 3, $szPingLines);
	
	if ($? != 0)
	{
		Logger->GetInstance()->Write($self, 1, "Ping failed. Charts server not available!");
	}
	else
	{
		Logger->GetInstance()->Write($self, 2, "Loading chart lists from the web ...");
			
		$self->{paszNotFoundSongs} = [];
		
		my $fLoadingChartsFailed = 1;
		foreach my $szChartsName ( "Top100", "Dance", "UK", "US" )
		{
			if (  $self->AddCharts( $szChartsName )  )
			{
				$fLoadingChartsFailed = 0;
			}
		}
		
		if ($fLoadingChartsFailed == 0)
		{
			$self->{pmpszCharts}->{nTimeStamp} = time();
			
			
			if (  @{ $self->{paszNotFoundSongs} } >= 1  )
			{
				Logger->GetInstance()->Write($self, 2, "The following charts could not be found in the music dir");
				foreach my $szSong (@{ $self->{paszNotFoundSongs} })
				{
					Logger->GetInstance()->Write($self, 3, $szSong);
				}
				
				
				if ($fDownloadChartsIfNotAvailable == 1)
	 			{
					my @aszGSNotFoundSongs = ();
					my $pobjGrooveSharkDownloader = GrooveSharkDownloader->new( $self->{pobjConfig} );
					foreach my $szSong (@{ $self->{paszNotFoundSongs} })
					{
						unless (  $pobjGrooveSharkDownloader->DownloadBestMatch( $szSong )  )
						{
							push @aszGSNotFoundSongs, $szSong;
						}
						
					}
					
					if (  @aszGSNotFoundSongs >= 1  )
					{
						Logger->GetInstance()->Write($self, 2, "The following charts could not be found on the grooveshark server");
						foreach my $szSong (@aszGSNotFoundSongs)
						{
							Logger->GetInstance()->Write($self, 3, $szSong);
						}
					}
					
					
					MPDCtrl->GetInstance()->updateDatabase();
					
					# Chart listen noch einmal laden, aber nict versuchen erneut aus dem Internet zu laden
					$self->load(0);
				}
			}
		}
	}
}

########################################################################################################################
sub AddCharts
########################################################################################################################
{
	my ($self, $szChartsName) = @_;
	
	my $pobjUserAgent = LWP::UserAgent->new();
	$pobjUserAgent->timeout(10);
	$pobjUserAgent->env_proxy();
	$pobjUserAgent->agent('Mozilla/5.0');
	
	my $szURL = $self->{pobjConfig}->GetChartsURL($szChartsName);	
	my $pobjtest = $pobjUserAgent->get( $szURL );
	my $szHTMLCode = $pobjUserAgent->get( $szURL )->decoded_content();
	my $pobjTokeParser = HTML::TokeParser->new( \$szHTMLCode );
	
	
	Logger->GetInstance()->Write($self, 2, "Following songs in $szChartsName found:");
	Logger->GetInstance()->Write($self, 3, "URL: $szURL");
	
	
	my %mpnCharts = ();
	while ( my $paszTag = $pobjTokeParser->get_tag("a") )
	{
        my $szPosition = $pobjTokeParser->get_trimmed_text("/span");
		next if ($szPosition eq "" or $szPosition !~ m/(\d+)/);
		my $nPosition = $1;
		
		my $szSong = $self->GetHTMLAttributeValue( $paszTag, "title" );
		next if ($szSong eq "" or $szSong !~ m/\-/);
		$szSong =~ s/Video nicht verfügbar: //i;
		$szSong =~ s/&amp;/&/ig;
		
		Logger->GetInstance()->Write($self, 3, "Pos $nPosition: $szSong");
		
		my $paszSongs = MPDCtrl->GetInstance()->GetSongs( $szSong );
		if (@$paszSongs >= 1)
		{
			foreach my $szFoundSong (@$paszSongs)
			{
				Logger->GetInstance()->Write($self, 3, "=> $szFoundSong");
				
				$mpnCharts{$szFoundSong} = $nPosition;
			}
		}
		else
		{
			# TODO fehlende songs gleich herunterladen
			push @{ $self->{paszNotFoundSongs} }, $szSong;
		}
		
		
	}
	
	if ( (keys %mpnCharts) >= 1)
	{
		$self->{pmpszCharts}->{$szChartsName} = \%mpnCharts;
		
		return 1;
	}
	else
	{
		Logger->GetInstance()->Write($self, 1, "Could not find a song for the charts list '$szChartsName'");
		
		return 0;
	}
}

########################################################################################################################
sub GetHTMLAttributeValue
########################################################################################################################
{
	my ($self, $paszTag, $szAttribute) = @_;
	
	if ( defined $paszTag->[1]->{$szAttribute} )
	{
		return $paszTag->[1]->{$szAttribute};
	}
	else
	{
		return "";
	}
}

########################################################################################################################
sub get
########################################################################################################################
{
	my ($self, $szChartsName) = @_;
	
	return $self->{pmpszCharts}->{$szChartsName};
}

########################################################################################################################
sub GetChartsList
########################################################################################################################
{
	my ($self, $szChartsName) = @_;
	
	# wird von Playlist für die Zufallswiedergabe über die Charts benötigt
	return keys %{ $self->{pmpszCharts}->{$szChartsName} };
}


1;

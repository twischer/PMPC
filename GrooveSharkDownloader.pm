package GrooveSharkDownloader;
use strict;
use warnings;
use utf8;
use File::Basename();
use File::Copy();
use File::Spec();
use Text::Levenshtein();
require Logger;

my $DONWLOADER_DIR = File::Spec->rel2abs( File::Basename::dirname($0)."/gsdownloader" );
my $DOWNLOADS = "gsdownloads";
my $MAX_DIFF = 10;


########################################################################################################################
sub new
########################################################################################################################
{
	my ($proto, $pobjConfig) = @_;
	
	my $self  = {};
		
	my $class = ref($proto) || $proto;
	bless ($self, $class);
	
	$self->{pobjConfig} = $pobjConfig;
	$self->{szLastSearch} = "";
	$self->{szLastSong} = "";
	$self->{hDownloader} = undef;
	$self->{nDownloaderPid} = -1;
	
	return $self;
}

########################################################################################################################
sub Search
########################################################################################################################
{
	my ($self, $szPattern) = @_;
	
	Logger->GetInstance()->Write($self, 2, "Looking for songs which match to '$szPattern' in the grooveshark database ...");
	$self->{szLastSearch} = $szPattern;
	
	$self->ExecuteDownloader("/l \"$szPattern\"");
	
	my @aszSongs = ();
	while (my $paszSong = $self->GetSong(1))
	{
		if ($paszSong->[0] ne "")
		{
			push @aszSongs, $paszSong;
		}
	}
	
	$self->CloseDownloader(0);
	
	return @aszSongs;
}

########################################################################################################################
sub GetSong
########################################################################################################################
{
	my ($self, $fBlocking) = @_;
	
	
	if ( defined (my $szLine = $self->GetLine($fBlocking)) )
	{
		my $szReturnSong = "";
		my $nPosition = 0;
		if ($szLine =~ m/^(\d+)\.\s(.+)$/)
		{
			my $szSong = $2;
			chomp($szSong);
			
			unless ($szSong =~ m/\//)
			{
				my $szSongFile = $DOWNLOADS . "/" . $szSong . ".mp3";
				unless (-f $self->{pobjConfig}->GetMusicDir()."/".$szSongFile)
				{
					$szReturnSong = $szSongFile;
					$nPosition = $1;
				}
			}
		}
		
		return [$szReturnSong, $nPosition];
	}
	else
	{
		return undef;
	}
}

########################################################################################################################
sub DownloadBestMatch
########################################################################################################################
{
	my ($self, $szSearchSong) = @_;
	
	$self->Search( $szSearchSong );
	
	my $nBestDiff = 0;
	my $nBestID = 0;
	my $szBestSong = "";
	while ( defined (my $paszSong = $self->GetSong(1)) )
	{
		my ($szDBSong, $nID) = @$paszSong;
		if ( $szDBSong and ($nID > 0) )
		{
			my $nDiff = Text::Levenshtein::distance( $szSearchSong, $szDBSong );
			
			if (  ($nDiff <= $MAX_DIFF) and ( ($nBestDiff > $nDiff) or ($nBestID <= 0) )  )
			{
				$nBestDiff = $nDiff;
				$nBestID = $nID;
				$szBestSong = $szDBSong;  
			}
		}
	}
	
	if ($nBestID >= 1)
	{
		$self->DownloadByID( $szBestSong, $nBestID );
		
		return 1;
	}
	else
	{
		return 0;
	}
}

########################################################################################################################
sub DownloadByID
########################################################################################################################
{
	my ($self, $szSong, $nID) = @_;
	
	Logger->GetInstance()->Write($self, 2, "Downloading song '$szSong' from the grooveshark server ...");
	
	$self->{nLastPercent} = 0;
	$self->{szLastSong} = $szSong;
	
	my $szSearchPattern = $self->{szLastSearch};
	if ( ($nID < 1) or ($nID > 200) )
	{
		$nID = 1;
		$szSearchPattern = $szSong;
	}
	
	$self->ExecuteDownloader("/d \"$szSearchPattern\" $nID");
	
	# auf Ende des downloads warten
	while ($self->GetStatus(1) < 100) {}
	
	$self->CloseDownloader(0);
}

########################################################################################################################
sub GetStatus
########################################################################################################################
{
	my ($self, $fBlocking) = @_;
	
	
	my $nPercent = $self->{nLastPercent};
	if ( defined (my $szLine = $self->GetLine($fBlocking)) )
	{
		if ($szLine =~ m/^\s*(\d+)\%/)
		{
			$nPercent = $1;
		}
	}
	else
	{
		$nPercent = 100;
	}
	
	
	if ($nPercent >= 100)
	{
		my $szSongFile = $self->{pobjConfig}->GetMusicDir()."/".$self->{szLastSong};
		
		Logger->GetInstance()->Write($self, 2, "Change gain of song...");
		
		my $szCmd = "mp3gain -r -k \"".$szSongFile."\" 2> /dev/null &";			# TODO nicht im hintergrund starten
		Logger->GetInstance()->Write($self, 3, $szCmd);
		system($szCmd);
	}
	
	$self->{nLastPercent} = $nPercent;
	
	return $nPercent;
}

########################################################################################################################
sub ExecuteDownloader
########################################################################################################################
{
	my ($self, $szArgs) = @_;
	
	
	my $szGSDir = $self->{pobjConfig}->GetMusicDir() . "/" . $DOWNLOADS;
	unless (-d $szGSDir)
	{
		mkdir $szGSDir or Logger->GetInstance()->Write($self, 0, "Could not create directory $szGSDir!");
	}
	
	my $szGrooveFixFile = $szGSDir . "/GrooveFix.xml";
	unless (-f $szGrooveFixFile)
	{
		File::Copy::copy( $DONWLOADER_DIR . "/GrooveFix.xml", $szGrooveFixFile );
	}
	
	
	# TODO aktuelles verzeichnis speichern
	chdir( $szGSDir );
	
	my $szCommand = "java -jar ".$DONWLOADER_DIR."/SciLorsJGroovesharkDownloader.jar /c ".$szArgs;
	Logger->GetInstance()->Write($self, 3, $szCommand );
	$self->{nDownloaderPid} = open ($self->{hDownloader}, $szCommand." 2>&1 |") or Logger->GetInstance()->Write($self, 0, "Could not open '$szCommand'!");
	
	chdir(  File::Basename::dirname( $0 )  );
}

########################################################################################################################
sub GetLine
########################################################################################################################
{
	my ($self, $fBlocking) = @_;
	
	
	$fBlocking = 0 unless (defined $fBlocking);
	
	my $szReturn = undef;
	
	my $pDownloader = $self->{hDownloader};
	if (defined $pDownloader)
	{
		$szReturn = "";
		
		my $rfd = '';
		vec($rfd, fileno($pDownloader), 1) = 1;

		if ( ($fBlocking == 1) or ( select($rfd, undef, undef, 0) >= 0 ) and ( vec($rfd, fileno($pDownloader), 1) )  )
		{
			if (my $szLine = <$pDownloader>)
			{
				utf8::decode($szLine);
				chomp($szLine);
				
				Logger->GetInstance()->Write($self, 3, $szLine);
				$szReturn = $szLine;
			}
			else
			{
				$self->CloseDownloader(0);
				
				$szReturn = undef;
			}
		}
	}
	
	return $szReturn;
}

########################################################################################################################
sub CloseDownloader
########################################################################################################################
{
	my ($self, $fAbortExecution) = @_;
	
	if (defined $self->{hDownloader})
	{
		kill("TERM", $self->{nDownloaderPid}) if ($fAbortExecution == 1);
		$self->{nDownloaderPid} = -1;

		close( $self->{hDownloader} );
		$self->{hDownloader} = undef;

		my $szSongFile = $self->{pobjConfig}->GetMusicDir()."/".$self->{szLastSong};
		if ( ($fAbortExecution == 1) and (-f $szSongFile) )
		{
			unlink $szSongFile or Logger->GetInstance()->Write($self, 1, "Could not remove file '$szSongFile' of aborted download");
		}
	}
}

1;

package Search;
use strict;
use warnings;
use utf8;
use File::Copy();
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
	
	# wird nur einmal erstellt weil der search string gespeichert werden muss
	$self->{pobjGrooveSharkDownloader} = GrooveSharkDownloader->new($pobjConfig);
	
	return $self;
}

########################################################################################################################
sub delete
########################################################################################################################
{
	my ($self) = @_;
	
}

########################################################################################################################
sub Search
########################################################################################################################
{
	my ($self, $szPattern) = @_;
	
	
	if ( (defined $szPattern) and ($szPattern ne "") )  
	{
		Logger->GetInstance()->Write($self, 2, "Looking for songs which match to '$szPattern' ...");
	
		my $paszSongs = MPDCtrl->GetInstance()->GetSongs( $szPattern );

		if ( (@$paszSongs <= 10) and ($self->{pobjConfig}->GetDownloadSong() == 1) )
		{
			push @$paszSongs, $self->{pobjGrooveSharkDownloader}->Search( $szPattern );
		}
		
		return $paszSongs;
	}
	else
	{
		return MPDCtrl->GetInstance()->GetSongs();
	}
}

########################################################################################################################
sub downloadSong
########################################################################################################################
{
	my ($self, $szSong, $nID) = @_;
	
	
	$self->{pobjGrooveSharkDownloader}->DownloadByID( $szSong, $nID );
	MPDCtrl->GetInstance()->updateDatabase("gsdownloads"),
}

1;

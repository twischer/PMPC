package Control;
use strict;
use warnings;
use utf8;
require Logger;
require MPDCtrl;


########################################################################################################################
sub new
########################################################################################################################
{
	my ($proto) = @_;
	
	my $self  = {};
		
	my $class = ref($proto) || $proto;
	bless ($self, $class);
	
	return $self;
}

########################################################################################################################
sub PlayOrPause
########################################################################################################################
{
	my ($self) = @_;
	
	MPDCtrl->GetInstance()->Toggle();
}

########################################################################################################################
sub Next
########################################################################################################################
{
	my ($self) = @_;
	
	MPDCtrl->GetInstance()->GetMPD()->next();
}

########################################################################################################################
sub getInfo
########################################################################################################################
{
	my ($self) = @_;
	
	
	my $szSong = MPDCtrl->GetInstance()->GetCurrentSong();
	
	my $nTimeElapsed = MPDCtrl->GetInstance()->GetElapsedTime();
	my $nTimeTotal = MPDCtrl->GetInstance()->GetTotalTime();
	
	my $dFraction = $nTimeElapsed / $nTimeTotal;
	if ( ($dFraction < 0.0) and ($dFraction > 1.0) )
	{
		$dFraction = 0.0;
	}
	
	my $szTimeInfo = sprintf( "%02d:%02d / %02d:%02d", int($nTimeElapsed / 60), ($nTimeElapsed % 60), int($nTimeTotal / 60), ($nTimeTotal % 60) );

	my $fIsPlaying = MPDCtrl->GetInstance()->IsPlaying();
	
	
	return ($szSong, $dFraction, $szTimeInfo, $fIsPlaying);
}

1;

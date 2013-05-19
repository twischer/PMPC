package LightningServer;
use strict;
use warnings;
use utf8;
use IO::Socket();
require Logger;
require MPDCtrl;

########################################################################################################################
sub new
########################################################################################################################
{
	my ($proto, $pobjConfig) = @_;
	
	my $self  = {};
		
	my $class = ref($proto) || $proto;
	bless ($self, $class);
	
	
	if ($pobjConfig->GetLightningActive() == 1)
	{
		$self->{pobjServer} = IO::Socket::INET->new(
			'Proto'		=> "tcp",
			'LocalPort'	=> $pobjConfig->GetLightningPort(),
			'Listen'	=> $IO::Socket::SOMAXCONN,
			'Reuse'		=> 1,
			'Timeout'	=> 1,
			);
		
		if ( $self->{pobjServer} )
		{
			Logger->GetInstance()->Write($self, 2, "Server was started.");
		}
		else
		{
			Logger->GetInstance()->Write($self, 1, "Server could not start on port ".$pobjConfig->GetLightningPort().".");
		}
	}
	
	return $self;
}

########################################################################################################################
sub delete
########################################################################################################################
{
	my ($self) = @_;
	
	if ( $self->{pobjClient} )
	{
		close( $self->{pobjClient} );
	}
	
	if ( $self->{pobjServer} )
	{
		close( $self->{pobjServer} );
	}
}

########################################################################################################################
sub SendButtonStats
########################################################################################################################
{
	my ($self, @afState) = @_;
	
	if (  ( not $self->{pobjClient} ) or ( not $self->{pobjClient}->connected() )  )
	{
		Logger->GetInstance()->Write($self, 2, "Try to connect to a new client.");
		
		$self->{pobjClient} = $self->{pobjServer}->accept();
		
		if ( $self->{pobjClient} )
		{
			foreach my $ni (1..32)
			{
				$self->SendButtonStat( $ni, 0, 52 );
			}
		}
	}
	
	if ( $self->{pobjClient} )
	{
		Logger->GetInstance()->Write($self, 2, "Sending changed button stats ...");
		
		my $nChannel = 1;
		foreach my $fState (@afState)
		{
			my $nButtonValue = ($fState == 1) ? 5119 : 0;
			
			Logger->GetInstance()->Write($self, 3, "Send for channel $nChannel value $nButtonValue.");
			$self->SendButtonStat( $nChannel, $nButtonValue );
			
			$nChannel++;
		}
	}
	else
	{
		Logger->GetInstance()->Write($self, 1, "Could not peer with client.");
	}
}

########################################################################################################################
sub SendButtonStat
########################################################################################################################
{
	my ($self, $nChannel, $nValue, $nInit) = @_;
	
	unless (defined $nInit)
	{
		$nInit = 0x00;
	}
	
	my $bData = pack( "CCS", $nChannel, $nInit, $nValue );
	$self->{pobjClient}->send( $bData );
}

1;

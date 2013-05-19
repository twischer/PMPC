package Preview;
use strict;
use warnings;
use utf8;
use GStreamer();
use Time::HiRes();
GStreamer->init();

########################################################################################################################
sub new
########################################################################################################################
{
	my ($proto, $pobjConfig) = @_;
	
	my $self  = {};
	
	my $class = ref($proto) || $proto;
	bless ($self, $class);
	
	$self->{pobjConfig} = $pobjConfig;
	$self->{fFileLoaded} = 0;
	
	
	if ($pobjConfig->GetPreviewActive() == 1)
	{
		$self->{pobjGStreamer} = GStreamer::ElementFactory->make("playbin2", "player");
		
		my $szALSADevice = $pobjConfig->GetALSADevicePreview();
		if ( (defined $szALSADevice) and ($szALSADevice ne "") and ($szALSADevice ne "Default Gstreamer Device") )
		{
			$self->{pobjGStreamerOut} = GStreamer::ElementFactory->make("alsasink", "output");
			$self->{pobjGStreamerOut}->set_property( "device", $szALSADevice );
			$self->{pobjGStreamer}->set_property("audio-sink", $self->{pobjGStreamerOut} );
		}
	}
	
	return $self;
}

########################################################################################################################
sub DESTROY
########################################################################################################################
{
	my ($self) = @_;
	# unref
}

########################################################################################################################
sub play
########################################################################################################################
{
	my ($self, $szSong) = @_;
	
	if ($self->{pobjConfig}->GetPreviewActive() == 1)
	{
		my $szFile = $self->{pobjConfig}->GetMusicDir() . "/" . $szSong;
		
		$self->{fFileLoaded} = 0;
		$self->{pobjGStreamer}->set_state("null");
			
		if (-f $szFile)
		{
			$self->{pobjGStreamer}->set_property(  "uri", Glib::filename_to_uri( $szFile, "localhost" )  );
			$self->{pobjGStreamer}->set_state("playing");
			
			$self->{fFileLoaded} = 1;
			
			return $self->getDuration();
		}
		else
		{
			return 0;
		}
	}
	else
	{
		return 0;
	}
}

########################################################################################################################
sub getDuration
########################################################################################################################
{
	my ($self) = @_;
	
	
	my $pobjDuration = GStreamer::Query::Duration->new("time");
	my $nDuration = 0;
	while ($nDuration <= 0)
	{
		$self->{pobjGStreamer}->query($pobjDuration);
		$nDuration = int($pobjDuration->duration / 1_000_000_000);
	}
	
	
	return $nDuration;
}

########################################################################################################################
sub getPosition
########################################################################################################################
{
	my ($self) = @_;
	
	
	my $pobjPosition = GStreamer::Query::Position->new("time");
	if ( ($self->{fFileLoaded} == 1) and $self->{pobjGStreamer}->query($pobjPosition) )
	{
		return int($pobjPosition->position / 1_000_000_000);
	}
	else
	{
		return 0;
	}
}

########################################################################################################################
sub changePosition
########################################################################################################################
{
	my ($self, $nNewPosTime) = @_;
	
	
	if ($self->{fFileLoaded} == 1)
	{
		my $fLastVolume = $self->{pobjGStreamer}->get_property( "volume" );
		$self->{pobjGStreamer}->set_property( "volume", 0.0 );
		$self->{pobjGStreamer}->seek(1.0, 'GST_FORMAT_TIME', 'GST_SEEK_FLAG_FLUSH', 'GST_SEEK_TYPE_SET', $nNewPosTime * 1_000_000_000, 'GST_SEEK_TYPE_NONE', 0);
		
		Time::HiRes::sleep( 0.1 );
		$self->{pobjGStreamer}->set_property( "volume", $fLastVolume );
	}
}

########################################################################################################################
sub GetDeviceList
########################################################################################################################
{
	my ($self) = @_;
	
	my @aszDevices = ( "Default Gstreamer Device" );
	
	open( my $hAPlay, "aplay -L |" ) or Logger->GetInstance()->Write($self, 1, "Could not get the ALSA device list from aplay!");
	while (my $szLine = <$hAPlay>)
	{
		if ($szLine =~ m/^\w/)
		{
			chomp( $szLine );
			push @aszDevices, $szLine;
		}
	}
	close( $hAPlay );
	
	return @aszDevices;
}

1;

#! /usr/bin/perl -w
use strict;
use warnings;
use utf8;
use File::Basename();

chdir(  File::Basename::dirname( $0 )  );
require ViewThread;

my $m_nErrorLevel = ViewThread::show();
exit($m_nErrorLevel);

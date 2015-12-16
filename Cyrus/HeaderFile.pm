#!/usr/bin/perl -c

# Package to handle Cyrus Header files

package Cyrus::HeaderFile;

use strict;
use warnings;

use IO::File;
use IO::File::fcntl;
use IO::Handle;
use File::Temp;
use Data::Dumper;

our $HL1 = qq{\241\002\213\015Cyrus mailbox header};
our $HL2 = qq{"The best thing about this system was that it had lots of goals."};
our $HL3 = qq{\t--Jim Morris on Andrew};

# PUBLIC API

sub new {
  my $class = shift;
  my $handle = shift;

  # read header
  local $/ = undef;
  my $body = <$handle>;

  my $Self = bless {}, ref($class) || $class;
  $Self->{handle} = $handle; # keep for locking
  $Self->{rawheader} = $body;
  $Self->{header} = $Self->parse_header($body);

  return $Self;
}

sub new_file {
  my $class = shift;
  my $file = shift;
  my $lockopts = shift; 

  my $fh;
  if ($lockopts) {
    $lockopts = ['lock_ex'] unless ref($lockopts) eq 'ARRAY';
    $fh = IO::File::fcntl->new($file, '+<', @$lockopts)
          || die "Can't open $file for locked read: $!";
  } else {
    $fh = IO::File->new("< $file")
          || die "Can't open $file for read: $!";
  }

  return $class->new($fh);
}

sub header {
  my $Self = shift;
  my $Field = shift;

  if ($Field) {
    return $Self->{header}{$Field};
  }

  return $Self->{header};
}

sub write_header {
  my $Self = shift;
  my $fh = shift;
  my $header = shift;

  $fh->print($Self->make_header($header));
}

sub make_header {
  my $Self = shift;
  my $ds = shift;

  # NOTE: acl and flags should have '' as the last element!
  my $flags = join(" ", @{$ds->{Flags}}, '');
  my $acl = join("\t", @{$ds->{ACL}}, '');
  my $buf = <<EOF;
$HL1
$HL2
$HL3
$ds->{QuotaRoot}	$ds->{UniqueId}
$flags
$acl
EOF
  return $buf;
}

sub parse_header {
  my $Self = shift;
  my $body = shift;

  my @lines = split /\n/, $body;

  die "Not a mailbox header file" unless $lines[0] eq $HL1;
  die "Not a mailbox header file" unless $lines[1] eq $HL2;
  die "Not a mailbox header file" unless $lines[2] eq $HL3;
  my ($quotaroot, $uniqueid) = split /\t/, $lines[3];
  my (@flags) = split / /, $lines[4];
  my (@acl) = split /\t/, $lines[5];

  return {
    QuotaRoot => $quotaroot,
    UniqueId => $uniqueid,
    Flags => \@flags,
    ACL => \@acl,
  };
}

1;

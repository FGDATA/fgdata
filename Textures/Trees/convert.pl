#!/usr/bin/perl -w
#
# Simple script to generate .dds and low-rez versions of tree textures.
#

# Clean up temporary file that might have been left around
system("rm temp.png");

my @textures = glob("*.png");
my $tex;

foreach $tex (@textures) {
  # Get the current size
  my $base = $tex;
  $base =~ s/\.png//i;
  
  my $id = `identify $tex`;
  ($id =~ /\w+ PNG (\d+)x(\d+) /) || die ("Unable to parse output from identify: $id");	
  my $x = $1;
  my $y = $2;
  
  # Generate DDS version
  system("convert $tex -flip temp.png")        && die ("Unable to flip texture $!");
  system("nvcompress -bc3 temp.png $base.dds") && die ("Unable to nvcompress texture $tex: $!");
  system("rm temp.png")                        && die ("Unable to rm temp.png");
  
  # Generate lower resolution versions
  system("convert $tex -resize 50% ../../Textures/Trees/$tex")        && die ("Unable to resize texture $!");
  
  # Generate DDS version of low-rez
  system("convert ../../Textures/Trees/$tex -flip temp.png")        && die ("Unable to flip texture ../../Textures/Trees/$tex $!");
  system("nvcompress -bc3 temp.png ../../Textures/Trees/$base.dds") && die ("Unable to nvcompress texture ../../Textures/Trees/$tex: $!");
  system("rm temp.png")                                             && die ("Unable to rm temp.png");
  
}

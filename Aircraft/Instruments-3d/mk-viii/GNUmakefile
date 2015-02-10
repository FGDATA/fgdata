stylesheet = ../assembly/assembly.xsl

buttons = caution0 caution1 flap-override inhibit steep-approach terrain-inhibit warning0 warning1
lamps = glideslope-cancelled inop terrain-fail

output_files = $(foreach b,$(buttons),$(b).xml $(b)-actions.xml) $(foreach l,$(lamps),$(l).xml)

all_files = assembly.rgb $(output_files)

all: $(all_files)

$(output_files): mk-viii.xml $(stylesheet)
	xsltproc $(stylesheet) mk-viii.xml

assembly.rgb: ../assembly/assembly.rgb
	cp -p ../assembly/assembly.rgb ./

clean:
	rm -f $(all_files)

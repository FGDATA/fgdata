<?xml version="1.0"?>
<!DOCTYPE xsl:stylesheet>
<xsl:stylesheet version="1.1" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:variable name="model" select="concat(/assemblies/@fg-root, '/Aircraft/Instruments-3d/mk-viii/assembly/assembly.ac')"/>
  <xsl:variable name="texture-path">
    <xsl:if test="/assemblies/@texture-path"><xsl:value-of select="concat(/assemblies/@texture-path, '/')"/></xsl:if>
  </xsl:variable>

  <xsl:template name="generated">
    <xsl:comment>automatically generated, do not edit</xsl:comment>
  </xsl:template>

  <xsl:template match="assembly">
    <xsl:variable name="actions" select="concat(@name, '-actions.xml')"/>
    <xsl:variable name="prefix" select="concat('/controls/assemblies/', @name)"/>
    <xsl:variable name="button" select="concat($prefix, '-button')"/>
    <xsl:variable name="guard" select="concat($prefix, '-guard')"/>
    <xsl:variable name="guarded">
      <xsl:choose>
	<xsl:when test="@guarded='true'">true</xsl:when>
	<xsl:otherwise>false</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="latching">
      <xsl:choose>
	<xsl:when test="not(@input)">true</xsl:when>
	<xsl:otherwise>false</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="input">
      <xsl:choose>
	<xsl:when test="$latching='false'"><xsl:value-of select="@input"/></xsl:when>
	<xsl:otherwise><xsl:value-of select="$button"/></xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="emission-red">
      <xsl:choose>
	<xsl:when test="@emission-red"><xsl:value-of select="@emission-red"/></xsl:when>
	<xsl:otherwise><xsl:value-of select="/assemblies/@emission-red"/></xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="emission-green">
      <xsl:choose>
	<xsl:when test="@emission-green"><xsl:value-of select="@emission-green"/></xsl:when>
	<xsl:otherwise><xsl:value-of select="/assemblies/@emission-green"/></xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="emission-blue">
      <xsl:choose>
	<xsl:when test="@emission-blue"><xsl:value-of select="@emission-blue"/></xsl:when>
	<xsl:otherwise><xsl:value-of select="/assemblies/@emission-blue"/></xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="emission-factor">
      <xsl:choose>
	<xsl:when test="@emission-factor"><xsl:value-of select="@emission-factor"/></xsl:when>
	<xsl:otherwise><xsl:value-of select="/assemblies/@emission-factor"/></xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="texture-prefix">
      <xsl:choose>
	<xsl:when test="@texture"><xsl:value-of select="@texture"/></xsl:when>
	<xsl:otherwise><xsl:value-of select="@name"/></xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="texture-on" select="concat($texture-path, $texture-prefix, '-on.rgb')"/>
    <xsl:variable name="texture-off" select="concat($texture-path, $texture-prefix, '-off.rgb')"/>

    <xsl:document href="{@name}.xml" indent="yes">
      <xsl:call-template name="generated"/>
      <PropertyList>
	<path><xsl:value-of select="$model"/></path>

	<xsl:if test="@output">
	  <panel>
	    <path><xsl:value-of select="concat(/assemblies/@pwd, '/', $actions)"/></path>
	    <bottom-left>
	      <x-m>0.00314583</x-m>
	      <y-m>-0.00965716</y-m>
	      <z-m>-0.00965716</z-m>
	    </bottom-left>
	    <bottom-right>
	      <x-m>0.00314583</x-m>
	      <y-m>0.00965716</y-m>
	      <z-m>-0.00965716</z-m>
	    </bottom-right>
	    <top-left>
	      <x-m>0.00314583</x-m>
	      <y-m>-0.00965716</y-m>
	      <z-m>0.02897148</z-m>
	    </top-left>
	  </panel>

	  <animation>
	    <type>translate</type>
	    <object-name>lamp</object-name>
	    <property><xsl:value-of select="$button"/></property>
	    <factor>-0.0040</factor>
	    <axis>
	      <x>1.0</x>
	      <y>0.0</y>
	      <z>0.0</z>
	    </axis>
	  </animation>
	</xsl:if>

	<animation>
	  <type>select</type>
	  <object-name>guard</object-name>
	  <condition>
	    <xsl:choose>
	      <xsl:when test="$guarded='true'"><not><property>/null</property></not></xsl:when>
	      <xsl:otherwise><property>/null</property></xsl:otherwise>
	    </xsl:choose>
	  </condition>
	</animation>

	<xsl:if test="$guarded='true'">
	  <animation>
	    <type>rotate</type>
	    <object-name>guard</object-name>
	    <property><xsl:value-of select="$guard"/></property>
	    <factor>-90</factor>
	    <center>
	      <x-m>-0.00314583</x-m>
	      <y-m>0.0</y-m>
	      <z-m>0.00965716</z-m>
	    </center>
	    <axis>
	      <x>0.0</x>
	      <y>1.0</y>
	      <z>0.0</z>
	    </axis>
	  </animation>
	</xsl:if>
	    
	<animation>
	  <type>material</type>
	  <object-name>lamp-off</object-name>
	  <texture><xsl:value-of select="$texture-off"/></texture>
	</animation>

	<animation>
	  <type>material</type>
	  <object-name>lamp-on</object-name>
	  <texture><xsl:value-of select="$texture-on"/></texture>
	</animation>

	<animation>
	  <type>select</type>
	  <object-name>lamp-off</object-name>
	  <condition>
	    <not><property><xsl:value-of select="$input"/></property></not>
	  </condition>
	</animation>

	<animation>
	  <type>select</type>
	  <object-name>lamp-on</object-name>
	  <condition>
	    <property><xsl:value-of select="$input"/></property>
	  </condition>
	</animation>

	<animation>
	  <type>material</type>
	  <object-name>lamp-off</object-name>
	  <emission>
	    <red-prop><xsl:value-of select="$emission-red"/></red-prop>
	    <green-prop><xsl:value-of select="$emission-green"/></green-prop>
	    <blue-prop><xsl:value-of select="$emission-blue"/></blue-prop>
	    <factor-prop><xsl:value-of select="$emission-factor"/></factor-prop>
	  </emission>
	</animation>
      </PropertyList>
    </xsl:document>

    <xsl:if test="@output">
      <xsl:document href="{$actions}" indent="yes">
	<xsl:call-template name="generated"/>
	<PropertyList>
	  <background>Aircraft/Instruments-3d/mk-viii/assembly/transparent-bg.rgb</background>
	  <w>64</w>
	  <h>64</h>

	  <instruments>
	    <instrument>
	      <x>32</x>
	      <y>32</y>
	      <w>64</w>
	      <h>64</h>
	      <w-base>64</w-base>
	      <h-base>64</h-base>

	      <actions>
		<action>
		  <name>open guard or operate button</name>
		  <button>0</button>
		  <x>-32</x>
		  <y>-32</y>
		  <w>64</w>
		  <h>32</h>

		  <binding>
		    <command>press-cockpit-button</command>
		    <guarded><xsl:value-of select="$guarded"/></guarded>
		    <latching><xsl:value-of select="$latching"/></latching>
		    <prefix><xsl:value-of select="$prefix"/></prefix>
		    <discrete><xsl:value-of select="@output"/></discrete>
		  </binding>
		  
		  <mod-up>
		    <binding>
		      <command>release-cockpit-button</command>
		      <guarded><xsl:value-of select="$guarded"/></guarded>
		      <latching><xsl:value-of select="$latching"/></latching>
		      <prefix><xsl:value-of select="$prefix"/></prefix>
		      <discrete><xsl:value-of select="@output"/></discrete>
		    </binding>
		  </mod-up>
		</action>

		<xsl:if test="$guarded='true'">
		  <action>
		    <name>close guard</name>
		    <button>0</button>
		    <x>-32</x>
		    <y>0</y>
		    <w>64</w>
		    <h>32</h>

		    <binding>
		      <command>property-assign</command>
		      <property><xsl:value-of select="$guard"/></property>
		      <value type="double">0.0</value>
		    </binding>
		  </action>
		</xsl:if>
		
	      </actions>
	    </instrument>
	  </instruments>
	</PropertyList>
      </xsl:document>
    </xsl:if>
  </xsl:template>

  <xsl:template match="assemblies">
    <xsl:apply-templates select="*"/>
  </xsl:template>
</xsl:stylesheet>

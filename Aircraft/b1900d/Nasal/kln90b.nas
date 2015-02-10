#GPS KLN90B gps

var GPS = {
    new : func {
    m = { parents : [GPS]};
    m.supernav = 0;
    m.supernav_old = 0;
    m.Ltxt_offset=[15,100];
    m.Rtxt_offset=[270,520];
    m.Font="LiberationFonts/LiberationMono-Bold.ttf";
    m.blank="";
    m.txtsize=32;
    m.txtaspect=[1.2,1.0];
    m.gps_display = canvas.new({"name": "Screen","size": [512, 256],"view": [512, 256],"mipmapping": 0});
    m.gps_display.addPlacement({"node": "KLN90B.screen"});
    m.gps_display.setColorBackground(0.0, 0.0, 0.0, 1);
    m.gps_group = m.gps_display.createGroup();
    m.L1 = m.gps_group.createChild("text", "").setTranslation(m.Ltxt_offset[m.supernav], 20).setAlignment("left-center")
                .setFont(m.Font).setFontSize(m.txtsize, m.txtaspect[m.supernav]).setColor(0,1,0).setText("");
    m.L2 = m.gps_group.createChild("text", "").setTranslation(m.Ltxt_offset[m.supernav], 55).setAlignment("left-center")
                .setFont(m.Font).setFontSize(m.txtsize, m.txtaspect[m.supernav]).setColor(0,1,0).setText("");
    m.L3 = m.gps_group.createChild("text", "").setTranslation(m.Ltxt_offset[m.supernav], 90).setAlignment("left-center")
                .setFont(m.Font).setFontSize(m.txtsize, m.txtaspect[m.supernav]).setColor(0,1,0).setText("");
    m.L4 = m.gps_group.createChild("text", "").setTranslation(m.Ltxt_offset[m.supernav], 125).setAlignment("left-center")
                .setFont(m.Font).setFontSize(m.txtsize, m.txtaspect[m.supernav]).setColor(0,1,0).setText("");
    m.L5 = m.gps_group.createChild("text", "").setTranslation(m.Ltxt_offset[m.supernav], 160).setAlignment("left-center")
                .setFont(m.Font).setFontSize(m.txtsize, m.txtaspect[m.supernav]).setColor(0,1,0).setText("");
    m.L6 = m.gps_group.createChild("text", "").setTranslation(m.Ltxt_offset[m.supernav], 195).setAlignment("left-center")
                .setFont(m.Font).setFontSize(m.txtsize, m.txtaspect[m.supernav]).setColor(0,1,0).setText("");
    m.L7 = m.gps_group.createChild("text", "").setTranslation(m.Ltxt_offset[m.supernav], 235).setAlignment("left-center")
                .setFont(m.Font).setFontSize(32, 1.6).setColor(0,1,0).setText("");
    m.R1 = m.gps_group.createChild("text", "").setTranslation(m.Rtxt_offset[m.supernav], 20).setAlignment("left-center")
                .setFont(m.Font).setFontSize(m.txtsize, m.txtaspect[m.supernav]).setColor(0,1,0).setText("");
    m.R2 = m.gps_group.createChild("text", "").setTranslation(m.Rtxt_offset[m.supernav], 55).setAlignment("left-center")
                .setFont(m.Font).setFontSize(m.txtsize, m.txtaspect[m.supernav]).setColor(0,1,0).setText("");
    m.R3 = m.gps_group.createChild("text", "").setTranslation(m.Rtxt_offset[m.supernav], 90).setAlignment("left-center")
                .setFont(m.Font).setFontSize(m.txtsize, m.txtaspect[m.supernav]).setColor(0,1,0).setText("");
    m.R4 = m.gps_group.createChild("text", "").setTranslation(m.Rtxt_offset[m.supernav], 125).setAlignment("left-center")
                .setFont(m.Font).setFontSize(m.txtsize, m.txtaspect[m.supernav]).setColor(0,1,0).setText("");
    m.R5 = m.gps_group.createChild("text", "").setTranslation(m.Rtxt_offset[m.supernav], 160).setAlignment("left-center")
                .setFont(m.Font).setFontSize(m.txtsize, m.txtaspect[m.supernav]).setColor(0,1,0).setText("");
    m.R6 = m.gps_group.createChild("text", "").setTranslation(m.Rtxt_offset[m.supernav], 195).setAlignment("left-center")
                .setFont(m.Font).setFontSize(m.txtsize, m.txtaspect[m.supernav]).setColor(0,1,0).setText("");
    m.R7 = m.gps_group.createChild("text", "").setTranslation(435, 235).setAlignment("left-center")
                .setFont(m.Font).setFontSize(32, 1.6).setColor(0,1,0).setText("");
    m.gps_status_bar =  m.gps_group.createChild("path").moveTo(5, 215).lineTo(505,215)
       .moveTo(95, 215).lineTo(95,255)
       .moveTo(425, 215).lineTo(425,255)
        .setStrokeLineWidth(3)
       .setColor(0,1,0);
       m.gps_divider =  m.gps_group.createChild("path").moveTo(256, 215).lineTo(256,60)
        .setStrokeLineWidth(3)
       .setColor(0,1,0);
       
       
       
    m.counter = 0;
    m.Lpage=["TRI ","MOD ","FPL ","NAV ","CAL ","STA ","SET ","OTH "];
    m.Rpage=["CTR ","REF ","ACT ","D/T ","NAV ","APT ","VOR ","NDB ","INT ","SUP "];
    m.Menu1 = 3;
    m.Menu2 = 4;
    m.Page1 = 0;
    m.Page2 = 0;
    m.LHstring=[];
    m.RHstring=[];
    m.lpage_max=[7,2,25,5,7,4,9,4];
    m.rpage_max=[2,1,25,4,5,8,1,1,1,1];
    m.PWR=0;
    m.gps = props.globals.initNode("instrumentation/gps");
    m.gps_annun = props.globals.initNode("instrumentation/gps-annunciator");
    m.LHmenu = m.gps_annun.initNode("LHmenu");
    m.RHmenu = m.gps_annun.initNode("RHmenu");
    m.serviceable = m.gps.initNode("serviceable",0,"BOOL");
    m.pwr=props.globals.initNode("systems/electrical/outputs/gps",0.0);
    m.dtrk=m.gps.initNode("wp/wp[1]/desired-course-deg",0.0);
    for(var i=0; i<7; i+=1) {
        append(m.LHstring,m.LHmenu.initNode("row["~i~"]","","STRING"));
        append(m.RHstring,m.RHmenu.initNode("row["~i~"]","","STRING"));
    }
    m.LHstring[6].setValue(m.Lpage[m.Menu1]~(m.Page1+1));
    m.RHstring[6].setValue(m.Rpage[m.Menu2]~(m.Page2+1));
    m.slaved = props.globals.initNode("instrumentation/nav/slaved-to-gps",0,"BOOL");
    m.legmode = m.gps.initNode("leg-mode");
    m.appr = m.gps.initNode("approach-active",0,"BOOL");
    
    m.Lpower = setlistener(m.serviceable, func m.power_up(),1,0);
    return m;
    },
##################
    draw_display : func(){
        me.supernav=0;

        if(me.Menu1==3 and me.Menu2==4){
            if(me.Page1==0 and me.Page2==0) me.supernav=1;
        }

        if(me.PWR == 0){
            for(var i=0; i<7; i+=1) {
                me.LHstring[i].setValue("");
                me.RHstring[i].setValue("");
            }
            me.LHstring[6].setValue("POWER OFF");
            me.RHstring[6].setValue("POWER OFF");
        }else{
            if(me.counter==0)me.setmode1();
            if(me.counter!=0)me.setmode2();
        }
        me.counter =1 - me.counter;
    },
##################
    power_up : func{
        me.PWR=me.serviceable.getValue();
        if(!me.PWR){
            setprop("instrumentation/gps/wp/wp[1]/waypoint-type","");
            setprop("/instrumentation/gps/wp/wp[1]/ID","");
            setprop("instrumentation/gps/wp/wp[1]/name","");
        }
    },
################## update left screen display ####################################
    setmode1: func(){
        if(me.Menu1 == 0){
            me.set_TRI1();
        }elsif(me.Menu1 == 1){
            me.set_MOD1();
        }elsif(me.Menu1 == 2){
            me.set_FPL1();
        }elsif(me.Menu1 == 3){
            me.set_NAV1();
        }elsif(me.Menu1 == 4){
            me.set_CAL1();
        }elsif(me.Menu1 == 5){
            me.set_STA1();
        }elsif(me.Menu1 == 6){
            me.set_SET1();
        }elsif(me.Menu1 == 7){
            me.set_OTH1();
        }
    },
##################  update right screen display ####################################
    setmode2: func(){
        if(me.Menu2 == 0){
            me.set_CTR2();
        }elsif(me.Menu2 == 1){
            me.set_REF2();
        }elsif(me.Menu2 == 2){
            me.set_ACT2();
        }elsif(me.Menu2 == 3){
            me.set_DT2();
        }elsif(me.Menu2 == 4){
            me.set_NAV2();
        }elsif(me.Menu2 == 5){
            me.set_APT2();
        }elsif(me.Menu2 == 6){
            me.set_VOR2();
        }elsif(me.Menu2 == 7){
            me.set_NDB2();
        }elsif(me.Menu2 == 8){
            me.set_INT2();
        }elsif(me.Menu2 == 9){
            me.set_SUP2();
        }
    },

#################################

    LH_erase: func(){
        for(var i=0; i<6; i+=1) {
            me.LHstring[i].setValue("");
        }
    },

    RH_erase: func(){
        for(var i=0; i<6; i+=1) {
            me.RHstring[i].setValue("");
        }
    },

################################
#######Update Pages ############
###############################
####### LEFT MENU ###########
#############################
    set_TRI1: func {
    },
################
    set_MOD1: func {
    },
###############
    set_FPL1: func {
    },
################
    set_NAV1: func {
        if(me.Page1==0){
            me.draw_nav1(me.LHstring);
        }elsif(me.Page1==1){
            me.draw_nav2(me.LHstring);
        }elsif(me.Page1==2){
            me.draw_nav3(me.LHstring);
        }elsif(me.Page1==3){
            me.draw_nav4(me.LHstring);
        }elsif(me.Page1==4){
            me.draw_nav5(me.LHstring);
        }
    },
#################
    set_CAL1: func {
    },
#################
    set_STA1: func {
    },
##################
    set_SET1: func {
    },
##################
    set_OTH1: func {
    },
##############################
####### RIGHT MENU ###########
##############################
    set_CTR2: func {
    },
#################
    set_REF2: func {
    },
################
    set_ACT2: func {
    },
#################
    set_DT2: func {
    },
################
    set_NAV2: func {
        if(me.Page2==0){
            me.draw_nav1(me.RHstring);
        }elsif(me.Page2==1){
            me.draw_nav2(me.RHstring);
        }elsif(me.Page2==2){
            me.draw_nav3(me.RHstring);
        }elsif(me.Page2==3){
            me.draw_nav4(me.RHstring);
        }elsif(me.Page2==4){
            me.draw_nav5(me.RHstring);
        }
    },
###################
    set_APT2: func {
    },
###################
    set_VOR2: func {
    },
##################
    set_NDB2: func {
    },
#################
    set_INT2: func {
    },
##################
    set_SUP2: func {
    },

##################  KLN90B knobs ##############################
    lh_menu : func (test){
        if(me.PWR != 0){
            me.Menu1 +=test;
            if(me.Menu1 > 7)me.Menu1 = 0;
            if(me.Menu1 < 0)me.Menu1 = 7;
            me.LHstring[6].setValue(me.Lpage[me.Menu1]~(me.Page1+1));
            me.Page1=0;
            me.LH_erase();
        }
    },

    lh_page : func (test){
        if(me.PWR != 0){
            me.Page1 +=test;
            if(me.Page1 > me.lpage_max[me.Menu1])me.Page1 = 0;
            if(me.Page1 < 0)me.Page1 = me.lpage_max[me.Menu1];
            me.LHstring[6].setValue(me.Lpage[me.Menu1]~(me.Page1+1));
            me.LH_erase();
        }
    },

    rh_menu : func (test){
        if(me.PWR != 0){
            me.Menu2 +=test;
            if(me.Menu2 > 9)me.Menu2 = 0;
            if(me.Menu2 < 0)me.Menu2 = 9;
            me.RHstring[6].setValue(me.Rpage[me.Menu2]~(me.Page2+1));
            me.Page2=0;
            me.RH_erase();
        }
 },

    rh_page : func (test){
        if(me.PWR != 0){
            me.Page2 +=test;
            if(me.Page2 > me.rpage_max[me.Menu2])me.Page2 = 0;
            if(me.Page2 < 0)me.Page2 = me.rpage_max[me.Menu2];
            me.RHstring[6].setValue(me.Rpage[me.Menu2]~(me.Page2+1));
            me.RH_erase();
        }
    },

################## Supernav1 update ######################
    align_update : func {
        var idx1=[20,215];
        
        me.L1.setTranslation(me.Ltxt_offset[me.supernav], 20).setFontSize(me.txtsize, me.txtaspect[me.supernav]);
        me.L2.setTranslation(me.Ltxt_offset[me.supernav], 55).setFontSize(me.txtsize, me.txtaspect[me.supernav]);
        me.L3.setTranslation(me.Ltxt_offset[me.supernav], 90).setFontSize(me.txtsize, me.txtaspect[me.supernav]);
        me.L4.setTranslation(me.Ltxt_offset[me.supernav], 125).setFontSize(me.txtsize, me.txtaspect[me.supernav]);
        me.L5.setTranslation(me.Ltxt_offset[me.supernav], 160).setFontSize(me.txtsize, me.txtaspect[me.supernav]);
        me.L6.setTranslation(me.Ltxt_offset[me.supernav], 195).setFontSize(me.txtsize, me.txtaspect[me.supernav]);
        me.R1.setTranslation(me.Rtxt_offset[me.supernav], 20);
        me.R2.setTranslation(me.Rtxt_offset[me.supernav], 55);
        me.R3.setTranslation(me.Rtxt_offset[me.supernav], 90);
        me.R4.setTranslation(me.Rtxt_offset[me.supernav], 125);
        me.R5.setTranslation(me.Rtxt_offset[me.supernav], 160);
        me.R6.setTranslation(me.Rtxt_offset[me.supernav], 195);
        me.supernav_old=me.supernav;
        me.gps_divider.setBool("visible",1-me.supernav);
        },

    ############# NAV PAGES ######################
    draw_nav1 : func(addr){
        var buf="";
        var ID=getprop("instrumentation/gps/wp/wp/ID") or "D";
        var ID2=getprop("instrumentation/gps/wp/wp[1]/ID") or "";
        buf = sprintf("   %s > %s",ID,ID2);
        addr[0].setValue(buf);
        addr[1].setValue("  *****^*****");
        var DIS=getprop("instrumentation/gps/wp/wp[1]/distance-nm");
        buf = sprintf("DIS     % 4.0fNM",DIS);
        addr[2].setValue(buf);
        var GS=getprop("velocities/groundspeed-kt");
        buf = sprintf("GS     % 3.0fKT",GS);
        addr[3].setValue(buf);
        var ETE=getprop("instrumentation/gps/wp/wp[1]/TTW");
        buf = sprintf("ETE  %s",ETE);
        addr[4].setValue(buf);
        var BRG=getprop("instrumentation/gps/wp/wp[1]/bearing-mag-deg");
        buf = sprintf("BRG       %03.0f",BRG);
        addr[5].setValue(buf);
    },
    draw_nav2 : func(addr){
        var buf="";
        addr[0].setValue("PRESENT POS");
        addr[1].setValue(" ");
        addr[2].setValue(" ");
        addr[3].setValue(" ");
        addr[4].setValue(getprop("position/latitude-string"));
        addr[5].setValue(getprop("position/longitude-string"));
    },
        draw_nav3 : func(addr){
        var buf="";
        var ID=getprop("instrumentation/gps/wp/wp/ID");
        if(ID==nil)ID="D";
        var ID2=getprop("instrumentation/gps/wp/wp[1]/ID");
        if(ID2==nil)ID2=" ";
        buf = sprintf("   %s > %s",ID,ID2);
        addr[0].setValue(buf);
        var dtrk =getprop("instrumentation/gps/tracking-bug");
        buf = sprintf("DTK   %3.0f",dtrk);
        addr[1].setValue(buf);
        var atrk=getprop("instrumentation/gps/indicated-track-true-deg");
        buf = sprintf("TK   %3.0f",atrk);
        addr[2].setValue(buf);
        addr[3].setValue("FLY");
        addr[4].setValue("MSA 3000");
        addr[5].setValue("ESA 3700");
    },
    draw_nav4 : func(addr){
        addr[0].setValue(" ");
        addr[1].setValue(" ");
        addr[2].setValue(" ");
        addr[3].setValue(" ");
        addr[4].setValue(" ");
        addr[5].setValue(" ");
    },
    draw_nav5 : func(addr){
        addr[0].setValue(" ");
        addr[1].setValue(" ");
        addr[2].setValue(" ");
        addr[3].setValue(" ");
        addr[4].setValue(" ");
        addr[5].setValue(" ");
    },
 };
#########################################################

var Gps = GPS.new();

setlistener("sim/signals/fdm-initialized", func {
    setprop("instrumentation/gps/wp/wp/ID",getprop("sim/tower/airport-id"));
    setprop("instrumentation/gps/wp/wp/waypoint-type","airport");
    print("KLN-90B GPS  ...Check");
    settimer(update_gps,5);
    });

var update_gps = func {

    if(Gps.supernav!=Gps.supernav_old)Gps.align_update();
    Gps.draw_display();

    if(Gps.counter){
        Gps.L1.setText(getprop("instrumentation/gps-annunciator/LHmenu/row[0]"));
        Gps.L2.setText(getprop("instrumentation/gps-annunciator/LHmenu/row[1]"));
        Gps.L3.setText(getprop("instrumentation/gps-annunciator/LHmenu/row[2]"));
        Gps.L4.setText(getprop("instrumentation/gps-annunciator/LHmenu/row[3]"));
        Gps.L5.setText(getprop("instrumentation/gps-annunciator/LHmenu/row[4]"));
        Gps.L6.setText(getprop("instrumentation/gps-annunciator/LHmenu/row[5]"));
        Gps.L7.setText(getprop("instrumentation/gps-annunciator/LHmenu/row[6]"));
    }else{
        Gps.R1.setText(getprop("instrumentation/gps-annunciator/RHmenu/row[0]"));
        Gps.R2.setText(getprop("instrumentation/gps-annunciator/RHmenu/row[1]"));
        Gps.R3.setText(getprop("instrumentation/gps-annunciator/RHmenu/row[2]"));
        Gps.R4.setText(getprop("instrumentation/gps-annunciator/RHmenu/row[3]"));
        Gps.R5.setText(getprop("instrumentation/gps-annunciator/RHmenu/row[4]"));
        Gps.R6.setText(getprop("instrumentation/gps-annunciator/RHmenu/row[5]"));
        Gps.R7.setText(getprop("instrumentation/gps-annunciator/RHmenu/row[6]"));
    }
    settimer(update_gps,0);
}


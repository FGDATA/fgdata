####    jet engine hydraulics system    ####
####    Hyde Yamakawa    ####

var HYDR = {
    new : func(prop1){
        var m = { parents : [HYDR]};
        m.hydr = props.globals.initNode(prop1);
        m.LEDP = m.hydr.initNode("LEDP", 0, "BOOL");
        m.REDP = m.hydr.initNode("REDP", 0, "BOOL");
        m.C1ACMP = m.hydr.initNode("C1ACMP", 0, "BOOL");
        m.C2ACMP = m.hydr.initNode("C2ACMP", 0, "BOOL");
        m.LACMP = m.hydr.initNode("LACMP", 0, "BOOL");
        m.RACMP = m.hydr.initNode("RACMP", 0, "BOOL");
        m.C1ADP = m.hydr.initNode("C1ADP", 0, "BOOL");
        m.C2ADP = m.hydr.initNode("C2ADP", 0, "BOOL");
        m.LEDP_fine = m.hydr.initNode("LEDP-NORMAL", 0, "BOOL");
        m.REDP_fine = m.hydr.initNode("REDP-NORMAL", 0, "BOOL");
        m.C1ACMP_fine = m.hydr.initNode("C1ACMP-NORMAL", 0, "BOOL");
        m.C2ACMP_fine = m.hydr.initNode("C2ACMP-NORMAL", 0, "BOOL");
        m.LACMP_fine = m.hydr.initNode("LACMP-NORMAL", 0, "BOOL");
        m.RACMP_fine = m.hydr.initNode("RACMP-NORMAL", 0, "BOOL");
        m.C1ADP_fine = m.hydr.initNode("C1ADP-NORMAL", 0, "BOOL");
        m.C2ADP_fine = m.hydr.initNode("C2ADP-NORMAL", 0, "BOOL");
        m.left = m.hydr.initNode("system-left", 0, "BOOL");
        m.center = m.hydr.initNode("system-center", 0, "BOOL");
        m.right = m.hydr.initNode("system-right", 0, "BOOL");
        m.leng_running = props.globals.getNode("engines/engine/run", 1);
        m.leng_primary_switch = props.globals.initNode("controls/hydraulics/system/LENG_switch", 1, "BOOL");
        m.reng_running = props.globals.getNode("engines/engine[1]/run", 1);
        m.reng_primary_switch = props.globals.initNode("controls/hydraulics/system[2]/RENG_switch", 1, "BOOL");
        m.c1elec_switch = props.globals.initNode("controls/hydraulics/system[1]/C1ELEC-switch", 0, "BOOL");
        m.c2elec_switch = props.globals.initNode("controls/hydraulics/system[1]/C2ELEC-switch", 0, "BOOL");
        m.lacmp_switch = props.globals.initNode("controls/hydraulics/system/LACMP-switch", 0, "INT");
        m.racmp_switch = props.globals.initNode("controls/hydraulics/system[2]/RACMP-switch", 0, "INT");
        m.c1adp_switch = props.globals.initNode("controls/hydraulics/system[1]/C1ADP-switch", 0, "INT");
        m.c2adp_switch = props.globals.initNode("controls/hydraulics/system[1]/C2ADP-switch", 0, "INT");
        return m;
    },
    update : func{
        if(me.leng_running.getValue() and me.leng_primary_switch.getValue())
        {
            me.LEDP.setValue(1);
            me.LEDP_fine.setValue(1);       #FALT light off
        }
        else
        {
            me.LEDP.setValue(0);
            if(cpt_flt_inst.getValue() > 24)
            {
                me.LEDP_fine.setValue(0);   #FALT light on
            }
            else
            {
                me.LEDP_fine.setValue(1);   #FALT light off
            }
        }
        if(me.reng_running.getValue() and me.reng_primary_switch.getValue())
        {
            me.REDP.setValue(1);
            me.REDP_fine.setValue(1);
        }
        else
        {
            me.REDP.setValue(0);
            if(cpt_flt_inst.getValue() > 24)
            {
                me.REDP_fine.setValue(0);
            }
            else
            {
                me.REDP_fine.setValue(1);
            }
        }
        if((lidg.get_output_volts() > 80) and me.c1elec_switch.getValue())
        {
            me.C1ACMP.setValue(1);
            me.C1ACMP_fine.setValue(1);
        }
        else
        {
            me.C1ACMP.setValue(0);
            if(cpt_flt_inst.getValue() > 24)
            {
                me.C1ACMP_fine.setValue(0);
            }
            else
            {
                me.C1ACMP_fine.setValue(1);
            }
        }
        if((lidg.get_output_volts() > 80) and me.c2elec_switch.getValue())
        {
            me.C2ACMP.setValue(1);
            me.C2ACMP_fine.setValue(1);
        }
        else
        {
            me.C2ACMP.setValue(0);
            if(cpt_flt_inst.getValue() > 24)
            {
                me.C2ACMP_fine.setValue(0);
            }
            else
            {
                me.C2ACMP_fine.setValue(1);
            }
        }
        if((lidg.get_output_volts() > 80) and me.lacmp_switch.getValue() > 0)
        {
            me.LACMP.setValue(1);
            me.LACMP_fine.setValue(1);
        }
        else
        {
            me.LACMP.setValue(0);
            if(cpt_flt_inst.getValue() > 24)
            {
                me.LACMP_fine.setValue(0);
            }
            else
            {
                me.LACMP_fine.setValue(1);
            }
        }
        if((lidg.get_output_volts() > 80) and me.racmp_switch.getValue() > 0)
        {
            me.RACMP.setValue(1);
            me.RACMP_fine.setValue(1);
        }
        else
        {
            me.RACMP.setValue(0);
            if(cpt_flt_inst.getValue() > 24)
            {
                me.RACMP_fine.setValue(0);
            }
            else
            {
                me.RACMP_fine.setValue(1);
            }
        }
        if((lidg.get_output_volts() > 80) and me.c1adp_switch.getValue() > 0)
        {
            me.C1ADP.setValue(1);
            me.C1ADP_fine.setValue(1);
        }
        else
        {
            me.C1ADP.setValue(0);
            if(cpt_flt_inst.getValue() > 24)
            {
                me.C1ADP_fine.setValue(0);
            }
            else
            {
                me.C1ADP_fine.setValue(1);
            }
        }
        if((lidg.get_output_volts() > 80) and me.c2adp_switch.getValue() > 0)
        {
            me.C2ADP.setValue(1);
            me.C2ADP_fine.setValue(1);
        }
        else
        {
            me.C2ADP.setValue(0);
            if(cpt_flt_inst.getValue() > 24)
            {
                me.C2ADP_fine.setValue(0);
            }
            else
            {
                me.C2ADP_fine.setValue(1);
            }
        }
        var elevatorpos = props.globals.initNode("surface-positions/elevator-pos-norm");
        var stabilizerpos = props.globals.initNode("surface-positions/stabilizer-pos-norm");
        var leftaileronpos = props.globals.initNode("surface-positions/left-aileron-pos-norm");
        var rightaileronpos = props.globals.initNode("surface-positions/right-aileron-pos-norm");
        var rudderpos = props.globals.initNode("surface-positions/rudder-pos-norm");
        var speedbkpos = props.globals.initNode("surface-positions/speedbrake-norm");
        elevatorpos.setAttribute("writable",0);
        stabilizerpos.setAttribute("writable",0);
        leftaileronpos.setAttribute("writable",0);
        rightaileronpos.setAttribute("writable",0);
        rudderpos.setAttribute("writable",0);
        speedbkpos.setAttribute("writable",0);

        # Left hydraulic system
        # flight controls, the left engine thrust reverser
        var reverserL = props.globals.initNode("surface-positions/reverser-norm");
        if(me.LEDP.getValue() or me.LACMP.getValue())
        {
            me.left.setValue(1);
            reverserL.setAttribute("writable",1);
            elevatorpos.setAttribute("writable",1);
            stabilizerpos.setAttribute("writable",1);
            leftaileronpos.setAttribute("writable",1);
            rightaileronpos.setAttribute("writable",1);
            rudderpos.setAttribute("writable",1);
            speedbkpos.setAttribute("writable",1);
        }
        else
        {
            me.left.setValue(0);
            reverserL.setAttribute("writable",0);
        }
        # right hydraulic system
        # flight controls, normal brakes, the right thrust reverser
        var reverserR = props.globals.initNode("surface-positions/reverser-norm[1]");
        if(me.REDP.getValue() or me.RACMP.getValue())
        {
            me.right.setValue(1);
            reverserR.setAttribute("writable",1);
            elevatorpos.setAttribute("writable",1);
            leftaileronpos.setAttribute("writable",1);
            rightaileronpos.setAttribute("writable",1);
            rudderpos.setAttribute("writable",1);
            speedbkpos.setAttribute("writable",1);
        }
        else
        {
            me.right.setValue(0);
            reverserR.setAttribute("writable",0);
        }
        # center hydraulic system
        # flight controls, leading edge slats, trailing edge flaps, landing gear actuation, alternate brakes
        # nose gear steering, main gear steering
        var flappos = props.globals.initNode("surface-positions/flap-pos-norm");
        var nosewheelpos =  props.globals.initNode("controls/gear/nosegear-steering-cmd-norm");
        var mainwheelpos =  props.globals.initNode("controls/gear/maingear-steering-cmd-norm");
        if(me.C1ACMP.getValue() or me.C2ACMP.getValue()
            or me.C1ADP.getValue() or me.C2ADP.getValue())
        {
            me.center.setValue(1);
            flappos.setAttribute("writable",1);
            nosewheelpos.setAttribute("writable",1);
            mainwheelpos.setAttribute("writable",1);
            elevatorpos.setAttribute("writable",1);
            leftaileronpos.setAttribute("writable",1);
            rightaileronpos.setAttribute("writable",1);
            rudderpos.setAttribute("writable",1);
            speedbkpos.setAttribute("writable",1);
        }
        else
        {
            me.center.setValue(0);
            flappos.setAttribute("writable",0);
            nosewheelpos.setAttribute("writable",0);
            mainwheelpos.setAttribute("writable",0);
        }
    }
};

var Hydr = HYDR.new("systems/hydraulics");

var update_hyderaulics = func {
    Hydr.update();
    settimer(update_hyderaulics, 0.2);
}

#####################################
    setlistener("sim/signals/fdm-initialized", func {
    Hydr.leng_primary_switch.setValue(1);
    Hydr.reng_primary_switch.setValue(1);
    settimer(update_hyderaulics,5);
});


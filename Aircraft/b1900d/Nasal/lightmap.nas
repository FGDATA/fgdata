#### this small script handle the intensity of the lightmap effect

#### the following values sets the intensity of the lightmap effect
var tail=1.6;
var beacon=1.8;
var landing=2.0;
var taxi=1.6;
setprop("sim/model/livery/alfa-lightfactor", 0);

#### manage tail-logo light
setlistener("systems/electrical/outputs/lights/logo-lights", func(LL){
    setprop("sim/model/livery/tail-logo-lightfactor",LL.getValue()*tail);
});

#### manage beacons light
setlistener("systems/electrical/outputs/lights/beacon", func(Bcn1){
  setprop("sim/model/livery/beacon-up-lightfactor",Bcn1.getValue()*beacon);
});

setlistener("systems/electrical/outputs/lights/beacon[1]", func(Bcn2){
  setprop("sim/model/livery/beacon-down-lightfactor",Bcn2.getValue()*beacon);
});


#### manage landing lights
setlistener ("systems/electrical/outputs/lights/landing-lights", func(Lnd1) {
    setprop("sim/model/livery/landing-light-left", Lnd1.getValue()*landing);
});

setlistener ("systems/electrical/outputs/lights/landing-lights[1]", func(Lnd2) {
    setprop("sim/model/livery/landing-light-right", Lnd2.getValue()*landing);
});

#### front landing light (not used at the moment)
setlistener ("systems/electrical/outputs/lights/taxi-lights", func(Tx){
  setprop("sim/model/livery/taxi-lightfactor", Tx.getValue()*taxi);
});

###############################################################################
##
## Zeppelin NT-07 airship for FlightGear.
## Passenger view configuration.
##
##  Copyright (C) 2010  Anders Gidenstam  (anders(at)gidenstam.org)
##  This file is licensed under the GPL license v2 or later.
##
###############################################################################

# Constraints
var carConstraint =
    walkview.makeUnionConstraint(
        [
         # Cockpit area.
         walkview.SlopingYAlignedPlane.new([19.1, -0.3, -8.85],
                                           [19.5,  0.3, -8.85]),
         # Passenger cabin.
         walkview.SlopingYAlignedPlane.new([19.5, -0.7, -9.08], 
                                           [26.4,  0.7, -9.08]),
         # Rear coach. Sit down when entering.
         walkview.ActionConstraint.new
             (walkview.SlopingYAlignedPlane.new([26.4, -0.5, -8.42], 
                                                [26.7,  0.5, -8.42]),
              func {
                  print("Seated!");
                  walker.set_eye_height(0.82);
              },
              func(x, y) {
                  if (x <= 0) {
                      print("Standing!");
                      walker.set_eye_height(1.60);
                  }
              })
        ]);

# The view manager.
var walker = walkview.Walker.new("Passenger View", carConstraint);


# Nasal functions for handling the checklists present under /sim/checklists

# Convert checklists into full tutorials.
var convert_checklists = func {

  if ((props.globals.getNode("/sim/checklists") != nil)                            and 
      (props.globals.getNode("/sim/checklists").getChildren("checklist") != nil)   and
      (size(props.globals.getNode("/sim/checklists").getChildren("checklist")) > 0)    )
  {
    var checklists = props.globals.getNode("/sim/checklists").getChildren("checklist");
    var tutorials = props.globals.getNode("/sim/tutorials", 1);

    foreach (var ch; checklists) {
      var name = ch.getNode("title", 1).getValue();
      var tutorial = tutorials.getNode("tutorial[" ~ size(tutorials.getChildren("tutorial")) ~ "]", 1);

      # Initial high level config
      tutorial.getNode("name", 1).setValue("Checklist: " ~ name);
      var description = 
        "Tutorial to run through the " ~ 
        name ~ 
        " checklist.\n\nChecklist available through the Help->Checklists menu.\n\n";
        
      var step = tutorial.getNode("step", 1);
      step.getNode("message", 1).setValue("Checklist: " ~ name);    
        
      # Now go through each of the checklist items and generate a tutorial step 
      # for each.
          
			# Checklist may consist of one or more pages.
			var pages = ch.getChildren("page");
			
			if (size(pages) == 0) {
				# Or no pages at all, in which case we need to create a checklist of one page
				append(pages, ch);
			}
			
			foreach (var page; pages) {
				foreach (var item; page.getChildren("item")) {
					step = tutorial.getNode("step["~ size(tutorial.getChildren("step")) ~ "]", 1);
					
					var msg = item.getNode("name", 1).getValue();
					
					if (size(item.getChildren("value")) > 0) {
						msg = msg ~ " :";
						foreach (var v; item.getChildren("value")) {
							msg = msg ~ " " ~ v.getValue();
						}
					}
								
					step.getNode("message", 1).setValue(msg);        
					description = description ~ msg ~ "\n";
					
					if (item.getNode("condition") != nil) {
						var cond = step.getNode("exit", 1).getNode("condition", 1);
						props.copy(item.getNode("condition"), cond);
					}      
					
					if (item.getNode("marker") != nil) {
						var marker= step.getNode("marker", 1);
						props.copy(item.getNode("marker"), marker);
					}      
					
				}
			}
      
      tutorial.getNode("description", 1).setValue(description);    
    }
  }
}

_setlistener("/sim/signals/nasal-dir-initialized", func {
  convert_checklists();
});

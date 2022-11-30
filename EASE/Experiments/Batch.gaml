/******************************************************************
* This file is part of project EASE, the revised GAMA CoVid19 Modeling Kit
* Relase 1.0, May 2020. See http://comokit.org for support and updates
* Author: rpabao
* 
* Description: 
* 	TO DO
* 
* Parameters:
* 	- TO DO
* Dataset: chosen by the user (through a choice popup)
* Tags: covid19,epidemiology,vaccine
******************************************************************/

model CoVid19

import "../../Model/Global.gaml"
import "../Abstract Experiment.gaml"

global {
	//@Override
	action define_policy{
		ask Authority {
			policy <- create_no_containment_policy();
		}
	}
}

experiment "Batch Intervention" parent: "Abstract Experiment" autorun: false {
	//map usr_input <- user_input("Selection",["Mask Efficacy" :: 0.9]);
	map usr_input <- user_input([
		enter("Days per Batch",5),
		enter("Number of break days (exclude non-working days)",5)
	]);
	
	action _init_ {
		string shape_path <- build_dataset_path();
		float simulation_seed <- rnd(2000.0);
		list<rgb> colors <- brewer_colors("Paired");
		// Set the various proportions [number of batch,number of week interval]
		list<list<float>> proportions <- [[1,0],[1,1],[2,0],[2,1]];
		int db <- int(usr_input at "Days per Batch");
		int bd <- int(usr_input at "Number of break days (exclude non-working days)");
		
		list<rgb> colorList <- [#red,#blue,#orange,#green];
		int i <- 0;
		loop proportion over: proportions {
			create simulation with: [color::colorList[i], 
				dataset_path::shape_path, seed::simulation_seed,
				batchcount::proportion[0],
				daysperbatch::db,
				daysinterval::proportion[1]*bd,
				force_parameters::list(epidemiological_proportion_wearing_mask, epidemiological_factor_wearing_mask)
			] {
				string batching <- (int(proportion[0])=1) ? "No batching " : (string(int(proportion[0])) + " batches ");
				string interval <- (int(proportion[1])=1) ? "with interval": "without interval";
				name <- batching + interval;
				// Automatically call define_policy action
			}
			i <- i+1;
		}
	}

	permanent {
		/*display "charts" parent: infected_cases refresh: every(24 #cycle) {
			graphics "title" {
				draw ("Day " + int((current_date - starting_date) /  #day))  font: default at: {100#px, 0} color:#white anchor: #top_left;
				draw  "Mask Efficacy " + round((1-factor) * 100) + "%" font: default at: {100#px, 30#px}  color: #white anchor: #top_left;
			}
		}*/
		
		display "charts" parent: infected_cases refresh: every(24 #cycle) {
			graphics "infected_cases" {
				//draw ("Day " + int((current_date - starting_date) /  #day))  font: default at: {100#px, 0} color:#black anchor: #top_left;
				draw  "Day: " + (int(cycle/24) + 1)  + " || Week " + (int((cycle/24)/7 + 1)) + " || Current Day: " + daynumtodayword(current_date.day_of_week)  font: default1 at: {70#px, 40#px} color:#black anchor: #top_left;
				//draw  "Batch# To Enter: " + getbatchtoenter() font: default at: {100#px, 80#px}  color: #grey anchor: #top_left;				
				//draw  "" + batchcount + " batch(es); " + daysperbatch + " day(s) per batch" font: default at: {100#px, 100#px}  color: #grey anchor: #top_left;				
			}
		}
		
		display "chart" parent: cumulative_incidence refresh: every(24 #cycle) {
			graphics "cumulative_incidence" {
				//draw ("Day " + int((current_date - starting_date) /  #day))  font: default at: {100#px, 0} color:#black anchor: #top_left;
				draw  "Day: " + (int(cycle/24) + 1)  + " || Week " + (int((cycle/24)/7 + 1)) + " || Current Day: " + daynumtodayword(current_date.day_of_week)  font: default1 at: {70#px, 40#px} color:#black anchor: #top_left;
				//draw  "Batch# To Enter: " + getbatchtoenter() font: default at: {100#px, 80#px}  color: #grey anchor: #top_left;				
				//draw  "" + batchcount + " batch(es); " + daysperbatch + " day(s) per batch" font: default at: {100#px, 100#px}  color: #grey anchor: #top_left;				
			}
		}
	}
	
	string isWorkingHour{
		if (!(current_date.hour between (univ_hour_open, univ_hour_close))) {	
			return " (Campus Closed) ";
		}
		else{
			return "";
		}
	}

	string isWorkingDay{
		if ((non_working_days one_matches (each = current_date.day_of_week))) {	
			return " (Campus Closed) ";
		}
		else{
			return "";
		}
	}
	string getbatchtoenter{
		if ((non_working_days one_matches (each = current_date.day_of_week))) {	
			return "N/A";
		}
		else if (batchtoenter = 0){
			return "N/A - Batch Break";
		}
		else{
			return string(batchtoenter);
		}		
	}
	string daynumtodayword(int d){
		list<string> dayoftheweek <- ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];
		return dayoftheweek[d - 1];
	}

	output {		
		layout #none consoles: false editors: false navigator: false tray: false tabs: false toolbars: false controls: true;

		//display "Main" parent: simple_display {
		display "Main" parent: default_display {
			//graphics title {
			//	draw world.name font: default at: {0, world.shape.height/2 - 30#px} color:world.color anchor: #top_left;
			//}
		}
		//display "Plot" parent: states_evolution_chart {
		//	graphics title {
		//		draw world.name font: default at: {50#px, 50#px} color:world.color anchor: #top_left;
		//	}
		//}
	}
}

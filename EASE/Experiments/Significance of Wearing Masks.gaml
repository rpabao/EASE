/******************************************************************
* This file is part of COMOKIT, the GAMA CoVid19 Modeling Kit
* Relase 1.0, May 2020. See http://comokit.org for support and updates
* Author: Alexis Drogoul, Damien Philippon
* Modified: rpabao
* 
* Description: 
* 	Model comparing various scenarios of wearing masks: either no one wears a mask or everybody wears one.
* 	The efficiency of masks to prevent disease transmission is parametrized (set to 0.1).
* 	No other intervention policy is added.
* 
* Parameters:
* 	- factor (defined in the experiment) sets the factor of reduction for successful contact rate of an infectious individual wearing mask 
* 	- proportions (in the _init_ action) sets the various the various proportions of the Individual population wearing a mask (set to 0% or 100%).
* 		One simulation is created for each element of the list. As an example, add 0.5 to test with 50% of the population wearing a mask.
* 
* Dataset: chosen by the user (through a choice popup)
* Tags: covid19,epidemiology,mask
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

experiment "Wearing Masks" parent: "Abstract Experiment" autorun: false {
	//map usr_input <- user_input("Selection",["Mask Effectiveness" :: 0.9]);
	map usr_input <- user_input([enter("% Mask Effectiveness",85,0,100,1)]);
	// Redefinition of the factor of successful contact rate of an infectious individual wearing mask (init_all_ages_factor_contact_rate_wearing_mask)
	float factor <- 1.0 - (float(usr_input at "% Mask Effectiveness")/100.0);

	action _init_ {
		//string shape_path <- self.ask_dataset_path();
		string shape_path <- build_dataset_path();
		float simulation_seed <- rnd(2000.0);
		list<rgb> colors <- brewer_colors("Paired");
		// Set the various proportions of the Individual population wearing a mask
		list<float> proportions <- [0.5,0.75,1.0];
		
		loop proportion over: proportions {
			create simulation with: [color::(colors at int(proportion*7)), dataset_path::shape_path, seed::simulation_seed,   
				init_all_ages_factor_contact_rate_wearing_mask::factor, 
				init_all_ages_proportion_wearing_mask::proportion, 
				force_parameters::list(epidemiological_proportion_wearing_mask, epidemiological_factor_wearing_mask)
			] {
				name <- string(int(proportion*100)) + "% mask compliance";
				// Automatically call define_policy action
			}
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
			graphics "title" {
				//draw ("Day " + int((current_date - starting_date) /  #day))  font: default at: {100#px, 0} color:#black anchor: #top_left;
				draw  "Day: " + (int(cycle/24) + 1)  + " || Week " + (int((cycle/24)/7 + 1)) + " || Current Day: " + daynumtodayword(current_date.day_of_week)  font: default1 at: {70#px, 40#px} color:#black anchor: #top_left;
				draw  "Mask Effectiveness: " + round((1-factor) * 100) + "%" font: default1 at: {70#px, 60#px}  color: #grey anchor: #top_left;
			}
		}
		
		display "chart" parent: cumulative_incidence refresh: every(24 #cycle) {
			graphics "title" {
				//draw ("Day " + int((current_date - starting_date) /  #day))  font: default at: {100#px, 0} color:#black anchor: #top_left;
				draw  "Day: " + (int(cycle/24) + 1)  + " || Week " + (int((cycle/24)/7 + 1)) + " || Current Day: " + daynumtodayword(current_date.day_of_week)  font: default1 at: {70#px, 40#px} color:#black anchor: #top_left;
				draw  "Mask Effectiveness: " + round((1-factor) * 100) + "%" font: default1 at: {70#px, 60#px}  color: #grey anchor: #top_left;
			}
		}
		
	}

	output {		
		layout #split consoles: false editors: false navigator: false tray: false tabs: false toolbars: false controls: true;

		//display "Main" parent: simple_display {
		display "Main" parent: default_display {
			//graphics title {
			//	draw world.name font: default at: {0, world.shape.height - 30#px} color:#white anchor: #top_left;
			//}
		}
		//display "Plot" parent: states_evolution_chart {
		//	graphics title {
		//		draw world.name font: default at: {50#px, 50#px} color:world.color anchor: #top_left;
		//	}
		//}
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
}

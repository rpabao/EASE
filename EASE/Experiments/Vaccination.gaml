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

experiment "Vaccine Intervention" parent: "Abstract Experiment" autorun: false {
	//map usr_input <- user_input("Selection",["Mask Efficacy" :: 0.9]);
	map usr_input <- user_input([
		enter("% effectiveness of fully vaccinated against infection",16.42,0,100,1),
		enter("% effectiveness of booster shot against infection",49.21,0,100,1)
	]);
	
	action _init_ {
		string shape_path <- build_dataset_path();
		float simulation_seed <- rnd(2000.0);
		float eff_full <- float(usr_input at "% effectiveness of fully vaccinated against infection")/100.0;
		float eff_boost <- float(usr_input at "% effectiveness of booster shot against infection")/100.0;
		list<rgb> colors <- brewer_colors("Paired");
		// Set the various proportions of the population who got 1st dose and 2nd dose vaccine
		list<list<float>> proportions <- [[1.0,0.0],[0.0,1.0],[0.5,0.5],[0.77463,0.17537]];
		
		list<rgb> colorList <- [#green,#red,#blue,#orange];
		int i <- 0;
		loop proportion over: proportions {
			//create simulation with: [color::(colors at int((proportion[0]*eff_full+proportion[1]*eff_boost)*40)), 
			create simulation with: [color::colorList[i], 
				dataset_path::shape_path, seed::simulation_seed,
				effectiveness_vaccine_2nddose::eff_full,
				effectiveness_vaccine_booster::eff_boost,
				proportion_vaccine_2nddose::proportion[0],
				proportion_vaccine_boosted::proportion[1], 
				force_parameters::list(epidemiological_proportion_wearing_mask, epidemiological_factor_wearing_mask)
			] {
				name <- string(int(proportion[0]*100)) + "% 2 doses only; " + string(int(proportion[1]*100)) + "% Boosted ";
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
				draw  "Effectiveness of 2 doses only: " + (effectiveness_vaccine_2nddose * 100) + "%"  font: default1 at: {70#px, 60#px}  color: #grey anchor: #top_left;
				draw  "Effectiveness with booster shot: " + (effectiveness_vaccine_booster * 100) + "%" font: default1 at: {70#px, 80#px}  color: #grey anchor: #top_left;
			}
		}
		
		display "chart" parent: cumulative_incidence refresh: every(24 #cycle) {
			graphics "cumulative_incidence" {
				//draw ("Day " + int((current_date - starting_date) /  #day))  font: default at: {100#px, 0} color:#black anchor: #top_left;
				draw  "Day: " + (int(cycle/24) + 1)  + " || Week " + (int((cycle/24)/7 + 1)) + " || Current Day: " + daynumtodayword(current_date.day_of_week)  font: default1 at: {70#px, 40#px} color:#black anchor: #top_left;
				draw  "Effectiveness of 2 doses only: " + (effectiveness_vaccine_2nddose * 100) + "%"  font: default1 at: {70#px, 60#px}  color: #grey anchor: #top_left;
				draw  "Effectiveness with booster shot: " + (effectiveness_vaccine_booster * 100) + "%" font: default1 at: {70#px, 80#px}  color: #grey anchor: #top_left;
			}
		}
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

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

experiment "Combined Intervention with batch comparison" parent: "Abstract Experiment" autorun: false {
	//map usr_input <- user_input("Selection",["Mask Efficacy" :: 0.9]);
	map usr_input <- user_input([
		enter("% Mask Effectiveness",85,0,100,1),
		//enter("% Mask Compliance",100,0,100,1),
		enter("% effectiveness of fully vaccinated against infection",16.42,0,100,1),
		enter("% effectiveness of booster shot against infection",49.21,0,100,1),
		//enter("Proportion of fully vaccinated",73.39,0,100,1),
		//enter("Proportion of boosted",16.61,0,100,1),
		//enter("Number of Batch",2),
		enter("Days per Batch",5),
		enter("Number of break days (exclude non-working days)",5)
	]);
	
	//float mask_compliance <- (float(usr_input at "% Mask Compliance")/100.0);
	float factor <- 1.0 - (float(usr_input at "% Mask Effectiveness")/100.0);
	//float pro_full <- float(usr_input at "Proportion of fully vaccinated")/100.0;
	//float pro_booster <- float(usr_input at "Proportion of boosted")/100.0;
	float eff_full <- float(usr_input at "% effectiveness of fully vaccinated against infection")/100.0;
	float eff_boost <- float(usr_input at "% effectiveness of booster shot against infection")/100.0;
	
	action _init_ {
		string shape_path <- build_dataset_path();
		float simulation_seed <- rnd(2000.0);
		
		list<list<float>> proportions <- [[0.85,0.77463,0.17537,2.0],[0.7,0.8,0.0,1.0],[1.0,0.0,1.0,2.0]];
		
		list<rgb> colors <- brewer_colors("Paired");
		//int bc <- int(usr_input at "Number of Batch"); 
		int db <- int(usr_input at "Days per Batch");
		int bd <- int(usr_input at "Number of break days (exclude non-working days)");
		
		list<string> names <- ["Case 1: Close to reality ","Case 2: Minimum Acceptable Scenario ","Case 3: Ideal Scenario "];
		list<rgb> colorList <- [#red,#blue,#green];
		int i <- 0;
		loop proportion over: proportions {
			create simulation with: [color::colorList[i], 
				dataset_path::shape_path, seed::simulation_seed,   
				effectiveness_vaccine_2nddose::eff_full,
				effectiveness_vaccine_booster::eff_boost,
				proportion_vaccine_2nddose::proportion[1],
				proportion_vaccine_boosted::proportion[2],
				batchcount::int(proportion[3]),
				daysperbatch::db,
				daysinterval::bd,
				init_all_ages_factor_contact_rate_wearing_mask::factor, 
				init_all_ages_proportion_wearing_mask::proportion[0], 
				force_parameters::list(epidemiological_proportion_wearing_mask, epidemiological_factor_wearing_mask)
			] {
				name <- names[i];
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
			graphics "title" {
				//draw ("Day " + int((current_date - starting_date) /  #day))  font: default at: {100#px, 0} color:#black anchor: #top_left;
				draw  "Day: " + (int(cycle/24) + 1)  + " || Week " + (int((cycle/24)/7 + 1)) + " || Current Day: " + daynumtodayword(current_date.day_of_week) + isWorkingDay() font: default at: {100#px, 20#px} color:#gray anchor: #top_left;
				//draw  "Mask Compliance " + round(mask_compliance * 100) + "%" + " || Mask Effectiveness: " + round((1-factor) * 100) + "%" font: default at: {100#px, 40#px}  color: #gray anchor: #top_left;
				//draw  "Fully Vaccinated: " + round(proportion_vaccine_2nddose * 100) + "%" + " || Boosted: " + round(proportion_vaccine_boosted * 100) + "%" font: default at: {100#px, 60#px}  color: #gray anchor: #top_left;
				//draw  "Current Day: " + daynumtodayword(current_date.day_of_week) + isWorkingDay() font: default at: {100#px, 60#px}  color: #black anchor: #top_left;
				//draw  "Batch# To Enter: " + getbatchtoenter() font: default at: {100#px, 80#px}  color: #black anchor: #top_left;				
				//draw  "" + batchcount + " batch(es); " + daysperbatch + " day(s) per batch" font: default at: {100#px, 80#px}  color: #gray anchor: #top_left;				
				//draw  "Current Hour: " + current_date.hour + ":00" + isWorkingHour() font: default at: {100#px, 120#px}  color: #black anchor: #top_left;
				
			}
		}
		
		
		display "charts" parent: infected_cases refresh: every(24 #cycle) {
			graphics "title" {
				//draw ("Day " + int((current_date - starting_date) /  #day))  font: default at: {100#px, 0} color:#black anchor: #top_left;
				draw  "Day: " + (int(cycle/24) + 1)  + " || Week " + (int((cycle/24)/7 + 1)) + " || Current Day: " + daynumtodayword(current_date.day_of_week)  font: default1 at: {70#px, 40#px} color:#black anchor: #top_left;
				//draw  "Mask Effectiveness: " + round((1-factor) * 100) + "%" font: default1 at: {70#px, 60#px}  color: #grey anchor: #top_left;
			}
		}
		
		display "chart" parent: cumulative_incidence refresh: every(24 #cycle) {
			graphics "title" {
				//draw ("Day " + int((current_date - starting_date) /  #day))  font: default at: {100#px, 0} color:#black anchor: #top_left;
				draw  "Day: " + (int(cycle/24) + 1)  + " || Week " + (int((cycle/24)/7 + 1)) + " || Current Day: " + daynumtodayword(current_date.day_of_week)  font: default1 at: {70#px, 40#px} color:#black anchor: #top_left;
				//draw  "Mask Effectiveness: " + round((1-factor) * 100) + "%" font: default1 at: {70#px, 60#px}  color: #grey anchor: #top_left;
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
		layout #split consoles: false editors: false navigator: false tray: false tabs: false toolbars: false controls: true;

		//display "Main" parent: simple_display {
		display "Main" parent: default_display {
			//graphics title {
			//	draw world.name font: default at: {0, world.shape.height/2 - 30#px} color:world.color anchor: #top_left;
			//}
		}
		//display "Plot" parent: states_evolution_chart {}
	}
}

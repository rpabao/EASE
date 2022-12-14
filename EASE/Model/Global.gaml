/******************************************************************
* This file is part of COMOKIT, the GAMA CoVid19 Modeling Kit
* Relase 1.0, May 2020. See http://comokit.org for support and updates
* 
* This file contains global declarations of actions and attributes, used
* mainly for the purpose of initialising the model in experiments
* 
* Author: Benoit Gaudou, Damien Philippon, Patrick Taillandier
* Tags: covid19,epidemiology
******************************************************************/

@no_experiment

model CoVid19

import "Entities/Building.gaml"
import "Entities/Individual.gaml"
import "Entities/Hospital.gaml"
import "Entities/Activity.gaml"
import "Entities/Boundary.gaml"
import "Entities/Authority.gaml"
import "Entities/Activity.gaml"
import "Entities/Policy.gaml"
import "Constants.gaml"
import "Parameters.gaml"
import "Synthetic Population.gaml"

global {
	geometry shape <- envelope(shp_buildings);
	outside the_outside;
	
	list<string> possible_homes ;  //building type that will be considered as home	
	map<string, list<string>> activities; //list of activities, and for each activity type, the list of possible building type
	
	
	
	map<int,map<string,list<string>>> map_epidemiological_parameters;
	action global_init {
		do init_building_type_parameters;
		
		do console_output("global init");
		if (shp_boundary != nil) {
			create Boundary from: shp_boundary;
		}
		if (shp_buildings != nil) {
			create Building from: shp_buildings 
			//with: [	type:: string(read(isOpen_shp_attribute))=yes ? (string(read(amenity_shp_attribute)) in special_bd ? string(read(amenity_shp_attribute)): string(read(type_shp_attribute)) ) : building_closed, 
			with: [	type:: string(read(isOpen_shp_attribute))=yes ? string(read(type_shp_attribute)) : building_closed, 
					//nb_households:: max(1,int(read(flat_shp_attribute))),
					open:: string(read(isOpen_shp_attribute)),
					nb_rooms:: int(read(nb_rooms_shp_attribute)),
					capacity:: int(read(capacity_shp_attribute))
			];
		}
		
		loop aBuilding_Type over: Building collect(each.type)
		{
			add 0 at: aBuilding_Type to: building_infections;
		}
		do console_output("building and boundary : done");
		create outside; 
		the_outside <- first(outside);
		do create_activities;
		do console_output("Activities : done");
		//do create_hospital;
		
		//list<Building> homes <- Building where (each.type in possible_homes);
		map<string,list<Building>> buildings_per_activity <- Building group_by (each.type);
		
		map<Building,float> working_places;
		loop wp over: possible_workplaces.keys {
			if (wp in buildings_per_activity.keys) {
					working_places <- working_places +  (buildings_per_activity[wp] as_map (each:: (each.shape.area * possible_workplaces[wp])));  
			}
		}
		
		/*
		//Set values for min and max student age
		min_student_age <- retirement_age;
		max_student_age <- 0;
		map<list<int>,list<Building>> schools;
		loop l over: possible_schools.keys {
			max_student_age <- max(max_student_age, max(l));
			min_student_age <- min(min_student_age, min(l));
			string type <- possible_schools[l];
			schools[l] <- (type in buildings_per_activity.keys) ? buildings_per_activity[type] : list<Building>([]);
		}
		*/
		
		
		do console_output("Start creating population from "+(csv_population!=nil?"file":"built-in generator"));	
		if(isUniversity){
			list<Building> open_buildings <- Building where (each.open = yes and each.type = "office");
			do create_university_population(open_buildings);
		}
		/* 
		else {
			if(csv_population != nil) {
				do create_population_from_file(working_places, schools, homes);
			} else {
				do create_population(working_places, schools, homes);
			}
			do assign_school_working_place(working_places,schools);
		}
		*/
		ask Individual {
			do initialise_epidemio;
		}
		
		ask int(length(Individual)*min(1.0,proportion_vaccine_1stdose+proportion_vaccine_2nddose+proportion_vaccine_boosted)) among Individual
		{
			do set_as_vaccinated_1stdose;
			
		}
		
		ask int(length(Individual)*min(1.0,proportion_vaccine_2nddose+proportion_vaccine_boosted)) among Individual where (each.is_vaccinated_1stdose)
		{
			do set_as_vaccinated_2nddose;
		}
		
		ask int(length(Individual)*min(1.0,proportion_vaccine_boosted)) among Individual where (each.is_vaccinated_2nddose)
		{
			do set_as_vaccinated_booster;
		}
		
		do create_social_networks;	
		
		do define_agenda;	

		ask num_infected_init among Individual {
			do define_new_case_infected;
		}
		
		total_number_individual <- length(Individual);

	}


	action init_building_type_parameters {
		csv_parameters <- csv_file(building_type_per_activity_parameters,",",true);
		matrix data <- matrix(csv_parameters);
		//Loading the different rows number for the parameters in the file
		loop i from: 0 to: data.rows-1{
			string activity_type <- data[0,i];
			list<string> bd_type;
			loop j from: 1 to: data.columns - 1 {
				if (data[j,i] != nil) {
					bd_type << data[j,i];
				}
				
			}
			activities[activity_type] <- bd_type;
		}
		remove key: act_studying from:activities;
		possible_homes<- activities[act_home];
		remove key: act_home from:activities;
		add all: activities[act_working] as_map (each::1.0) to: possible_workplaces;
		remove key: act_working from:activities;
	}

	
	//Action used to initialise epidemiological parameters according to the file and parameters forced by the user
	action init_epidemiological_parameters
	{
		//If there are any file given as an epidemiological parameters, then we get the parameters value from it
		if(load_epidemiological_parameter_from_file and file_exists(epidemiological_parameters))
		{
			csv_parameters <- csv_file(epidemiological_parameters,true);
			matrix data <- matrix(csv_parameters);
			map<string, list<int>> map_parameters;
			//Loading the different rows number for the parameters in the file
			list possible_parameters <- distinct(data column_at epidemiological_csv_column_name);
			loop i from: 0 to: data.rows-1{
				if(contains(map_parameters.keys, data[epidemiological_csv_column_name,i] ))
				{
					add i to: map_parameters[string(data[epidemiological_csv_column_name,i])];
				}
				else
				{
					list<int> tmp_list;
					add i to: tmp_list;
					add tmp_list to: map_parameters at: string(data[epidemiological_csv_column_name,i]);
				}
			}
			//Initalising the matrix of age dependent parameters and other non-age dependent parameters
			loop aKey over: map_parameters.keys {
				switch aKey{
					//Four parameters are not age dependent : allowing human to human transmission, allowing environmental contamination, 
					//and the parameters for environmental contamination
					match epidemiological_transmission_human{
						allow_transmission_human <- bool(data[epidemiological_csv_column_parameter_one,first(map_parameters[aKey])])!=nil?
							bool(data[epidemiological_csv_column_parameter_one,first(map_parameters[aKey])]):allow_transmission_human;
					}
					match epidemiological_transmission_building{
						allow_transmission_building <- bool(data[epidemiological_csv_column_parameter_one,first(map_parameters[aKey])])!=nil?
							bool(data[epidemiological_csv_column_parameter_one,first(map_parameters[aKey])]):allow_transmission_building;
					}
					match epidemiological_basic_viral_decrease{
						basic_viral_decrease <- float(data[epidemiological_csv_column_parameter_one,first(map_parameters[aKey])])!=nil?float(data[epidemiological_csv_column_parameter_one,first(map_parameters[aKey])]):basic_viral_decrease;
					}
					match epidemiological_successful_contact_rate_building{
						successful_contact_rate_building <- float(data[epidemiological_csv_column_parameter_one,first(map_parameters[aKey])])!=nil?float(data[epidemiological_csv_column_parameter_one,first(map_parameters[aKey])]):successful_contact_rate_building;
					}
					//all the other parameters could be defined as age dependent, and therefore, stocked in the matrix of parameters
					default{
						loop i from: 0 to:length(map_parameters[aKey])-1
						{
							int index_column <- map_parameters[aKey][i];
							list<string> tmp_list <- list(string(data[epidemiological_csv_column_detail,index_column]),string(data[epidemiological_csv_column_parameter_one,index_column]),string(data[epidemiological_csv_column_parameter_two,index_column]));
							
							//If the parameter was provided only once in the file, then the value will be used for all ages, 
							// else, different values would be loaded according to the age categories given, hence the age dependent matrix
							if(i=length(map_parameters[aKey])-1)
							{
								loop aYear from:int(data[epidemiological_csv_column_age,index_column]) to: max_age
								{
									if(contains(map_epidemiological_parameters.keys,aYear))
									{
										add tmp_list to: map_epidemiological_parameters[aYear] at: string(data[epidemiological_csv_column_name,index_column]);
									}
									else
									{
										map<string, list<string>> tmp_map;
										add tmp_list to: tmp_map at: string(data[epidemiological_csv_column_name,index_column]);
										add tmp_map to: map_epidemiological_parameters at: aYear;
									}
								}
							}
							else
							{
								loop aYear from: int(data[epidemiological_csv_column_age,index_column]) to: int(data[epidemiological_csv_column_age,map_parameters[aKey][i+1]])-1
								{
									if(contains(map_epidemiological_parameters.keys,aYear))
									{
										add tmp_list to: map_epidemiological_parameters[aYear] at: string(data[epidemiological_csv_column_name,index_column]);
									}
									else
									{
										map<string, list<string>> tmp_map;
										add tmp_list to: tmp_map at: string(data[epidemiological_csv_column_name,index_column]);
										add tmp_map to: map_epidemiological_parameters at: aYear;
									}
								}
							}
						}
					}
				}
			}
		}
		//In the case no file was provided, then we simply create the matrix from the default parameters, that are not age dependent
		else
		{
			loop aYear from:0 to: max_age
			{
				map<string, list<string>> tmp_map;
				add list(epidemiological_fixed,string(init_all_ages_successful_contact_rate_human)) to: tmp_map at: epidemiological_successful_contact_rate_human;
				add list(epidemiological_fixed,string(init_all_ages_factor_contact_rate_asymptomatic)) to: tmp_map at: epidemiological_factor_asymptomatic;
				add list(epidemiological_fixed,string(init_all_ages_proportion_asymptomatic)) to: tmp_map at: epidemiological_proportion_asymptomatic;
				add list(epidemiological_fixed,string(init_all_ages_proportion_dead_symptomatic)) to: tmp_map at: epidemiological_proportion_death_symptomatic;
				add list(epidemiological_fixed,string(basic_viral_release)) to: tmp_map at: epidemiological_basic_viral_release;
				add list(epidemiological_fixed,string(init_all_ages_probability_true_positive)) to: tmp_map at: epidemiological_probability_true_positive;
				add list(epidemiological_fixed,string(init_all_ages_probability_true_negative)) to: tmp_map at: epidemiological_probability_true_negative;
				add list(epidemiological_fixed,string(init_all_ages_proportion_wearing_mask)) to: tmp_map at: epidemiological_proportion_wearing_mask;
				add list(epidemiological_fixed,string(init_all_ages_factor_contact_rate_wearing_mask)) to: tmp_map at: epidemiological_factor_wearing_mask;
				add list(init_all_ages_distribution_type_incubation_period_symptomatic,string(init_all_ages_parameter_1_incubation_period_symptomatic),string(init_all_ages_parameter_2_incubation_period_symptomatic)) to: tmp_map at: epidemiological_incubation_period_symptomatic;
				add list(init_all_ages_distribution_type_incubation_period_asymptomatic,string(init_all_ages_parameter_1_incubation_period_asymptomatic),string(init_all_ages_parameter_2_incubation_period_asymptomatic)) to: tmp_map at: epidemiological_incubation_period_asymptomatic;
				add list(init_all_ages_distribution_type_serial_interval,string(init_all_ages_parameter_1_serial_interval),string(init_all_ages_parameter_2_serial_interval)) to: tmp_map at: epidemiological_serial_interval;
				add list(init_all_ages_distribution_type_reinfection_interval,string(init_all_ages_parameter_1_reinfection_interval),string(init_all_ages_parameter_2_reinfection_interval)) to: tmp_map at: epidemiological_reinfection_interval;
				add list(epidemiological_fixed,string(init_all_ages_proportion_hospitalisation)) to: tmp_map at: epidemiological_proportion_hospitalisation;
				add list(epidemiological_fixed,string(init_all_ages_proportion_icu)) to: tmp_map at: epidemiological_proportion_icu;
				add list(init_all_ages_distribution_type_infectious_period_symptomatic,string(init_all_ages_parameter_1_infectious_period_symptomatic),string(init_all_ages_parameter_2_infectious_period_symptomatic)) to: tmp_map at: epidemiological_infectious_period_symptomatic;
				add list(init_all_ages_distribution_type_infectious_period_asymptomatic,string(init_all_ages_parameter_1_infectious_period_asymptomatic),string(init_all_ages_parameter_2_infectious_period_asymptomatic)) to: tmp_map at: epidemiological_infectious_period_asymptomatic;
				add list(init_all_ages_distribution_type_onset_to_hospitalisation,string(init_all_ages_parameter_1_onset_to_hospitalisation),string(init_all_ages_parameter_2_onset_to_hospitalisation)) to: tmp_map at: epidemiological_onset_to_hospitalisation;
				add list(init_all_ages_distribution_type_hospitalisation_to_ICU,string(init_all_ages_parameter_1_hospitalisation_to_ICU),string(init_all_ages_parameter_2_hospitalisation_to_ICU)) to: tmp_map at: epidemiological_hospitalisation_to_ICU;
				add list(init_all_ages_distribution_type_stay_ICU,string(init_all_ages_parameter_1_stay_ICU),string(init_all_ages_parameter_2_stay_ICU)) to: tmp_map at: epidemiological_stay_ICU;
				add tmp_map to: map_epidemiological_parameters at: aYear;
			}
		}
		
		//In the case the user wanted to load parameters from the file, but change the value of some of them for an experiment, 
		// the force_parameters list should contain the key for the parameter, so that the value given will replace the one already
		// defined in the matrix
		loop aParameter over: force_parameters
		{
			list<string> list_value;
			switch aParameter
			{
				match epidemiological_successful_contact_rate_human{
					list_value <- list<string>(epidemiological_fixed,init_all_ages_successful_contact_rate_human);
				}
				match epidemiological_factor_asymptomatic{
					list_value <- list<string>(epidemiological_fixed,init_all_ages_factor_contact_rate_asymptomatic);
				}
				match epidemiological_proportion_asymptomatic{
					list_value <- list<string>(epidemiological_fixed,init_all_ages_proportion_asymptomatic);
				}
				match epidemiological_proportion_death_symptomatic{
					list_value <- list<string>(epidemiological_fixed,init_all_ages_proportion_dead_symptomatic);
				}
				match epidemiological_basic_viral_release{
					list_value <- list<string>(epidemiological_fixed,basic_viral_release);
				}
				match epidemiological_probability_true_positive{
					list_value <- list<string>(epidemiological_fixed,init_all_ages_probability_true_positive);
				}
				match epidemiological_probability_true_negative{
					list_value <- list<string>(epidemiological_fixed,init_all_ages_probability_true_negative);
				}
				match epidemiological_proportion_wearing_mask{
					list_value <- list<string>(epidemiological_fixed,init_all_ages_proportion_wearing_mask);
				}
				match epidemiological_factor_wearing_mask{
					list_value <- list<string>(epidemiological_fixed,init_all_ages_factor_contact_rate_wearing_mask);
				}
				match epidemiological_incubation_period_symptomatic{
					list_value <- list<string>(init_all_ages_distribution_type_incubation_period_symptomatic,string(init_all_ages_parameter_1_incubation_period_symptomatic),string(init_all_ages_parameter_2_incubation_period_symptomatic));
				}
				match epidemiological_incubation_period_asymptomatic{
					list_value <- list<string>(init_all_ages_distribution_type_incubation_period_asymptomatic,string(init_all_ages_parameter_1_incubation_period_asymptomatic),string(init_all_ages_parameter_2_incubation_period_asymptomatic));
				}
				match epidemiological_serial_interval{
					list_value <- list<string>(init_all_ages_distribution_type_serial_interval,string(init_all_ages_parameter_1_serial_interval));
				}
				match epidemiological_reinfection_interval{
					list_value <- list<string>(init_all_ages_distribution_type_reinfection_interval,string(init_all_ages_parameter_1_reinfection_interval),string(init_all_ages_parameter_2_reinfection_interval));
				}
				match epidemiological_infectious_period_symptomatic{
					list_value <- list<string>(init_all_ages_distribution_type_infectious_period_symptomatic,string(init_all_ages_parameter_1_infectious_period_symptomatic),string(init_all_ages_parameter_2_infectious_period_symptomatic));
				}
				match epidemiological_infectious_period_asymptomatic{
					list_value <- list<string>(init_all_ages_distribution_type_infectious_period_asymptomatic,string(init_all_ages_parameter_1_infectious_period_asymptomatic),string(init_all_ages_parameter_2_infectious_period_asymptomatic));
				}
				match epidemiological_proportion_hospitalisation{
					list_value <- list<string>(epidemiological_fixed,init_all_ages_proportion_hospitalisation);
				}
				match epidemiological_onset_to_hospitalisation{
					list_value <- list<string>(init_all_ages_distribution_type_onset_to_hospitalisation,string(init_all_ages_parameter_1_onset_to_hospitalisation),string(init_all_ages_parameter_2_onset_to_hospitalisation));
				}
				match epidemiological_proportion_icu{
					list_value <- list<string>(epidemiological_fixed,init_all_ages_proportion_icu);
				}
				match epidemiological_hospitalisation_to_ICU{
					list_value <- list<string>(init_all_ages_distribution_type_hospitalisation_to_ICU,string(init_all_ages_parameter_1_hospitalisation_to_ICU),string(init_all_ages_parameter_2_hospitalisation_to_ICU));
				}
				match epidemiological_stay_ICU{
					list_value <- list<string>(init_all_ages_distribution_type_stay_ICU,string(init_all_ages_parameter_1_stay_ICU),string(init_all_ages_parameter_2_stay_ICU));
				}
				default{
					
				}
				
			}
			if(list_value !=nil)
			{
				loop aYear from:0 to: max_age
				{
					map_epidemiological_parameters[aYear][aParameter] <- list_value;
				}
			}
		}
	}
	
	// Global debug mode to print in console all messages called from #console_output()
	bool DEBUG <- false;
	// the available level of debug among debug, error and warning (default = debug)
	string LEVEL init:"debug" among:["debug","error","warning"];
	// Simple print_out method
	action console_output(string output, string caller <- "Global.gaml", string level <- LEVEL) { 
		if DEBUG {
			string msg <- "["+caller+"] "+output; 
			switch level {
				match "error" {error msg;}
				match "warning" {warn msg;}
				default {write msg;}
			}
		}
	}

}
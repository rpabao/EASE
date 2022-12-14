/******************************************************************
* This file is part of COMOKIT, the GAMA CoVid19 Modeling Kit
* Relase 1.0, May 2020. See http://comokit.org for support and updates
* 
* The main species of COMOKIT: a Biological Entity that can perform 
* Activities in Buildings.
* Individuals maintain networks of family members, friends and colleagues
* In addition to the attributes and states inherited from its parent, 
* this species provides actions so that its agents can be tested, hospitalized, 
* infected, can infect others, wear masks, and so on.
* 
* Author: Huynh Quang Nghi, Patrick Taillandier, Damien Philippon
* Tags: covid19,epidemiology
******************************************************************/


@no_experiment

model CoVid19

import "../Functions.gaml"
import "Activity.gaml"
import "Building.gaml"
import "Biological Entity.gaml"


global
{
	int total_number_of_infected <- 0;
	int total_number_reported <- 0;
	int total_number_individual <- 0;
	int total_number_deaths <- 0;
	int total_number_hospitalised <- 0;
	int total_number_ICU <- 0;
	
	map<string, int> building_infections;
	map<int,int> total_incidence_age;
}

species Individual parent: BiologicalEntity schedules: shuffle(Individual where (each.clinical_status != dead)){
	//batch attribute
	int my_batch;
	int my_number;
	
	//Age of the individual
	int age;
	//Sex of the individual
	int sex; //0 M 1 F
	//employement status of the individual
	bool is_unemployed; 
	
	//Bool to consider only once the death
	bool is_counted_dead <- false;
	//Bool to consider only once the hospitalisation
	bool is_counted_hospitalised <- false;
	//Bool to consider only once the ICU
	bool is_counted_ICU <- false;
	//#############################################################
	//Location related attributes
	//#############################################################
	//ID of the household of the individual
	string household_id;
	//Bool to consider if the individual is at home
	bool is_at_home <- true;
	//Home building of the individual
	Building home;
	//School building of the individual (if student)
	Building school;
	//Working place of the individual (if working)
	Building working_place;
	//Relatives (i.e. same household) of the individual
	list<Individual> relatives;
	//Friends (i.e. possibility of leisure activities together) of the individual
	list<Individual> friends;
	//Colleagues (i.e. same working place) of the individual
	list<Individual> colleagues;
	//Current building of the individual
	Building current_place;
	//Bool to consider if the individual is outside of the commune
	bool is_outside <- false;
	
	//#############################################################
	//Agenda and activities attributes
	//#############################################################
	list<map<int, pair<Activity,list<Individual>>>> agenda_week;
	list<Individual> activity_fellows;
	Activity last_activity;
	map<Activity, map<string,list<Building>>> building_targets;
	
	//#############################################################
	//Intervention related attributes
	//#############################################################
	//Reduction in the transmission when wearing a mask (coughing prevented)
	float factor_contact_rate_wearing_mask;
	//Bool to consider not following interventions
	bool free_rider <- false;
	//Probability of wearing a mask per time step
	float proba_wearing_mask;
	//Bool to represent wearing a mask
	bool is_wearing_mask;
	//Bool to uniquely count positive
	bool is_already_positive <- false;
	//Probability of being infected outside base on Rt
	float prob_infection_outside;
	
	
	//#############################################################
	//Actions
	//#############################################################
	
	
	//Action to call when performing a test on a individual
	action test_individual
	{
		//If the Individual is infected, we check for true positive
		if(self.is_infected)
		{
			if(world.is_true_positive(self.age))
			{
				report_status <- tested_positive;
				if(is_already_positive=false){
					is_already_positive <- true;
					total_number_reported <- total_number_reported+1;
				}
			}
			else
			{
				report_status <- tested_negative;
			}
		}
		else
		{
			//If the Individual is not infected, we check for true negative
			if(world.is_true_negative(self.age))
			{
				report_status <- tested_negative;
				
			}
			else
			{
				report_status <- tested_positive;
				if(is_already_positive=false){
					is_already_positive <- true;
					total_number_reported <- total_number_reported+1;
				}
			}
		}
		last_test <- cycle;
	}
	//Initialise epidemiological parameters according to the age of the Entity
	action initialise_epidemio {
		factor_contact_rate_asymptomatic <- world.get_factor_contact_rate_asymptomatic(age);
		factor_contact_rate_wearing_mask <- world.get_factor_contact_rate_wearing_mask(age);
		basic_viral_release <- world.get_basic_viral_release(age);
		contact_rate <- world.get_contact_rate_human(age);
		proba_wearing_mask <- world.get_proba_wearing_mask(age);
		prob_infection_outside <- world.get_prob_infection_outside(age);
	}
	
	//Action to call to define a new case, obtaining different time to key events
	action define_new_case
	{
		do update_wear_mask();
		float proba <- 1.0;
		if(is_wearing_mask)
		{
			proba <- factor_contact_rate_wearing_mask;
		}
		
		if flip(proba){
			if(has_natural_immunity)
			{
				if(flip(1-protection_againts_reinfection)){
					do define_new_case_latent;
				}
			}
			else
			{
				if(is_vaccinated_booster)
				{
					if(flip(1-effectiveness_vaccine_booster))
					{
						do define_new_case_latent;
					}
				}
				else if(is_vaccinated_2nddose)
				{
					if(flip(1-effectiveness_vaccine_2nddose))
					{
						do define_new_case_latent;
					}
				}
				else if(is_vaccinated_1stdose)
				{
					if(flip(1-effectiveness_vaccine_1stdose))
					{
						do define_new_case_latent;
					}
				}
				else
				{
					do define_new_case_latent;
				}
			}
		}
	}
	
	action define_new_case_latent
	{
		//Add the new case to the total number of infected (not mandatorily known)
		total_number_of_infected <- total_number_of_infected +1;
		//Add the infection to the infections having been caused in the building
		if(building_infections.keys contains(current_place.type))
		{
			building_infections[current_place.type] <- building_infections[current_place.type] +1;
		}
		else
		{
			add 1 to: building_infections at: current_place.type;
		}
		//Add the infection to the infections of the same age
		if(total_incidence_age.keys contains(self.age))
		{
			total_incidence_age[self.age] <- total_incidence_age[self.age] +1;
		}
		else
		{
			add 1 to: total_incidence_age at: self.age;
		}
		
		
		//Set the status of the Individual to latent (i.e. not infectious)
		state <- "latent";
		if(world.is_asymptomatic(self.age)){
			is_symptomatic <- false;
			latent_period <- world.get_incubation_period_asymptomatic(self.age);
		}else{
			is_symptomatic <- true;
			//presymptomatic_period <- world.get_serial_interval(self.age);
			//latent_period <- presymptomatic_period<0?world.get_incubation_period_symptomatic(self.age)+presymptomatic_period:world.get_incubation_period_symptomatic(self.age);
			latent_period <- world.get_incubation_period_symptomatic(self.age);
		}
	}
	
	
	action define_new_case_infected
	{
		//Add the new case to the total number of infected (not mandatorily known)
		total_number_of_infected <- total_number_of_infected +1;
		//Add the infection to the infections having been caused in the building
		if(building_infections.keys contains(current_place.type))
		{
			building_infections[current_place.type] <- building_infections[current_place.type] +1;
		}
		else
		{
			add 1 to: building_infections at: current_place.type;
		}
		//Add the infection to the infections of the same age
		if(total_incidence_age.keys contains(self.age))
		{
			total_incidence_age[self.age] <- total_incidence_age[self.age] +1;
		}
		else
		{
			add 1 to: total_incidence_age at: self.age;
		}
		
		
		//Set the status of the Individual to latent (i.e. not infectious)
		state <- "latent";
		if(world.is_asymptomatic(self.age)){
			is_symptomatic <- false;
			state <- "asymptomatic";
		}else{
			is_symptomatic <- true;
			state <- "symptomatic";
		}
	}
	
	//Action to call to update wearing a mask for a time step
	action update_wear_mask
	{
		//If the Individual is a free rider, it will not care for masks
		if(free_rider)
		{
			is_wearing_mask <- false;
		}
		else
		{
			if(flip(proba_wearing_mask))
			{
				is_wearing_mask <- true;
			}
			else
			{
				is_wearing_mask <- false;
			}
		}
	}
	
	//Initialiase social network of the agents (colleagues, friends)
	action initialise_social_network(map<Building,list<Individual>> working_places, map<Building,list<Individual>> schools, map<int,list<Individual>> ind_per_age_cat) {
		
		int nb_friends <- max(0,round(gauss(nb_friends_mean,nb_friends_std)));
		loop i over: ind_per_age_cat.keys {
			if age < i {
				friends <- nb_friends among ind_per_age_cat[i];
				friends <- friends - self;
				break;
			}
		}
		// if not in a university simulation, we still need to assign colleagues
		if(not isUniversity){
			if (working_place != nil) {
				int nb_colleagues <- max(0,int(gauss(nb_work_colleagues_mean,nb_work_colleagues_std)));
				if nb_colleagues > 0 {
					colleagues <- nb_colleagues among (working_places[working_place] - self);
				}
			} 
			if (school != nil) {
				int nb_classmates <- max(0,int(gauss(nb_classmates_mean,nb_classmates_std)));
				if nb_classmates > 0 {
					colleagues <- nb_classmates among ((schools[school] where ((each.age >= (age -1)) and (each.age <= (age + 1))))- self);
				}
			}
		}
 	}
	
	
	//Action to call when entering a new building to update the list of individuals of the buildings
	action enter_building(Building b) {
		if(not is_outside)
		{
			current_place.nb_people <- max(0,current_place.nb_people-1);
		}
		if(b.nb_people < b.capacity)
		{
			b.nb_people <- b.nb_people + 1;
			if (current_place != nil ){
				current_place.individuals >> self;
			}	
			current_place <- b;
			is_at_home <- current_place = home;
			is_outside <- false;
			current_place.individuals << self;
			location <- any_location_in(current_place);
		}
		else
		{
			current_place <- the_outside;
			is_outside <- true;
		}
	}
	
	//#############################################################
	//Reflexes
	//#############################################################
	
	//Reflex to trigger infection when outside of the commune
	reflex become_infected_outside when: is_outside and state = susceptible {
		
		if flip(prob_infection_outside)
		{
			do define_new_case;
		}	
		
		/*if flip(prob_infection_outside)
		{
			do update_wear_mask();
			float proba <- 1.0;
			if(is_wearing_mask)
			{
				proba <- factor_contact_rate_wearing_mask;
			}
			
			if flip(proba){
				do define_new_case_latent;
			}
		}
		* 
		*/
		
	}
	
	//Reflex to trigger transmission to other individuals and environmental contamination
	reflex infect_others when: not is_outside and is_infectious
	{
		//Computation of the reduction of the transmission when being asymptomatic/presymptomatic and/or wearing mask
		float reduction_factor <- 1.0;
		if(is_asymptomatic)
		{
			reduction_factor <- reduction_factor * factor_contact_rate_asymptomatic;
		}
		//if(is_wearing_mask)
		//{
		//	reduction_factor <- reduction_factor * factor_contact_rate_wearing_mask;
		//}
		
		//Performing environmental contamination
		if(current_place!=nil)and(allow_transmission_building)
		{
			ask current_place
			{
				do add_viral_load(reduction_factor*myself.basic_viral_release);
			}
		}
		
		//Perform human to human transmission
		if allow_transmission_human {
			//If the Individual is at home, perform transmission on the household level with a higher factor
			if (is_at_home) {
				float proba <- contact_rate*reduction_factor;
				ask relatives where (each.is_at_home and flip(proba) and (each.state = susceptible)) {
		 			do define_new_case;
				}
				//if (current_place.nb_households > 1) {
				//	proba <- proba * reduction_coeff_all_buildings_inhabitants;
				//	ask current_place.individuals where (flip(proba) and (each.state = susceptible))
			 	//	{
			 	//		do define_new_case;
			 	//	}
				//}
				
			}
			else {
				//Perform transmission with people doing the activity explicitly with the Individual
				float proba <- contact_rate*reduction_factor;
				list<Individual> fellows <- activity_fellows where (flip(proba) and (each.state = susceptible));
				if (species(last_activity) != Activity) {
					fellows <- fellows where (each.current_place = current_place); 
					//fellows <- fellows where (each.current_place = current_place and each in colleagues); 
				}
				
				ask fellows {
					do define_new_case;
				}
				
				//Perform slightly reduced transmission with people not being involved in the activity but still being present
				proba <- proba * reduction_coeff_all_buildings_individuals;
				ask current_place.individuals where (flip(proba) and (each.state = susceptible))
		 		{
					do define_new_case;
		 		}
		 	}
		}
	}
	

	//Reflex to execute the agenda	
	reflex execute_agenda when:clinical_status!=dead{
		if ( define_is_symptomatic() or 
			(non_working_days one_matches (each = current_date.day_of_week)) or
			!(current_date.hour between (univ_hour_open, univ_hour_close)) ) {	
			is_outside <- true;
		}
		else{
			if(my_batch != batchtoenter){
				is_outside <- true;
			}
			else{
				pair<Activity,list<Individual>> act <- agenda_week[current_date.day_of_week - 1][current_date.hour];
				if (act.key != nil) {
					if (Authority[0].allows(self, act.key)) {
						int nb_fellows <- Authority[0].limitGroupActivity(self, act.key) - 1;
							if (nb_fellows > 0) {
							activity_fellows <-nb_fellows among act.value;
						} else {
							activity_fellows <- [];
						}
						
						map<Building,list<Individual>> bds_ind <-  act.key.find_target(self);
						if not empty(bds_ind) {
							Building bd <- any(bds_ind.keys);
							list<Individual> inds <- bds_ind[bd];
							activity_fellows <- activity_fellows + inds;
							last_activity <- act.key;
							do enter_building(bd);
							is_outside <- current_place = the_outside;
						} else {
							activity_fellows <- [];
						}
					}
				}
			}
		}
	}
	
	//Reflex to update disease cycle
	reflex update_epidemiology when:(state!=removed) {
		if(allow_transmission_building and (not is_infected)and(self.current_place!=nil))
		{
			if(flip(current_place.viral_load * world.get_contact_rate_building()))
			{
				do define_new_case();
			}
		}
		do update_wear_mask();
	}
	
	//Reflex to add to death monitor when dead
	reflex add_to_dead when:(clinical_status=dead)and(is_counted_dead=false){
		total_number_deaths <- total_number_deaths+1;
		is_counted_dead <- true;
	}
	//Reflex to add to hospitalized monitor when dead
	reflex add_to_hospitalised when:(is_hospitalised)and(is_counted_hospitalised=false){
		total_number_hospitalised <- total_number_hospitalised+1;
		is_counted_hospitalised <- true;
	}
	//Reflex to add to ICU monitor when dead
	reflex add_to_ICU when:(is_ICU)and(is_counted_ICU=false){
		total_number_ICU <- total_number_ICU+1;
		is_counted_ICU <- true;
	}
	aspect default {
		if not is_outside {
			draw shape color: state = latent ? #pink : ((state = symptomatic)or(state=asymptomatic)or(state=presymptomatic)? #red : #green);
		}
	}
}
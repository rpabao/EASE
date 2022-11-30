/******************************************************************
* This file is part of COMOKIT, the GAMA CoVid19 Modeling Kit
* Relase 1.0, May 2020. See http://comokit.org for support and updates
* 
* Buildings represent in COMOKIT spatial entities where Individuals gather 
* to undertake their Activities. They are provided with a viral load to
* enable environmental transmission. 
* 
* Author: Huynh Quang Nghi, Benoit Gaudou, Damien Philippon, Patrick Taillandier
* Tags: covid19,epidemiology
******************************************************************/

@no_experiment

model CoVid19

import "Individual.gaml"

global {
	
	// TODO : turn it into parameters, more generaly it may require to smoothly init building attribute
	// from shape_file not using only OSM standard (might be the internal standard though), but relying also on custom bindings
	// i.e. make it possible to say : the feature "type" in my shapefile is "typo" and "school" are "kindergarden"
	string type_shp_attribute <- "type";
	//string flat_shp_attribute <- "flats";
	string isOpen_shp_attribute <- "open";
	//string amenity_shp_attribute <- "amenity";
	string nb_rooms_shp_attribute <- "nb_rooms";
	string capacity_shp_attribute <- "capacity";
	string building_closed <- "closed";
	//list<string> special_bd <- ["cafeteria","chapel"]; 
}

species Building {
	//Is the building open
	string open;
	//Number of classrooms and laboratories
	int nb_rooms;
	//Capacity of the building
	int capacity;
	//Number of people inside the building
	int nb_people <- 0;
	//Viral load of the building
	float viral_load <- 0.0;
	//Type of the building
	string type <- "";
	//Building surrounding
	list<Building> neighbors;
	//Individuals present in the building
	list<Individual> individuals <- [];
	//Number of households in the building
	//int nb_households;
	
	//Action to return the neighbouring buildings
	list<Building> get_neighbors {
		if empty(neighbors) {
			neighbors <- Building at_distance building_neighbors_dist;
			if empty(neighbors) {
				neighbors << Building closest_to self;
			}
		}
		return neighbors;
	}
	
	//Action to add viral load to the building
	action add_viral_load(float value){
		if(allow_transmission_building)
		{
			viral_load <- min(1.0,viral_load+value);
		}
	}
	//Action to update the viral load (i.e. trigger decreases)
	reflex update_viral_load when: allow_transmission_building{
		viral_load <- max(0.0,viral_load - basic_viral_decrease/nb_step_for_one_day);
	}

	aspect default {
		draw shape color: #gray empty: true;
	}

}

species outside parent: Building ;

/******************************************************************
* This file is part of COMOKIT, the GAMA CoVid19 Modeling Kit
* Relase 1.0, May 2020. See http://comokit.org for support and updates
* 
* A special sub-species of Building where infected symptomatic people
* can be gathered, depending on the policies implemented.
* 
* Author: Huynh Quang Nghi, Damien Philippon
* Tags: covid19,epidemiology
******************************************************************/


@no_experiment

model CoVid19

import "Building.gaml"

global{
	//Number of hospital in the city
	//int number_hospital <- 1;
	int number_hospital <- 0;
	//Capacity of hospitalisation per hospital (this should be initialised by data, but we don't have any :))
	int capacity_hospitalisation_per_hospital <- 1000;
	//Capacity of ICU per hospital (this should be initialised by data, but we don't have any :))
	int capacity_ICU_per_hospital <- 100;
	
	//Action to create a hospital TO CHANGE WHEN DATA ARE AVAILABLE (which building to chose, what capacity)
	action create_hospital{
		create Hospital number:number_hospital{
			capacity_hospitalisation <- capacity_hospitalisation_per_hospital;
			capacity_ICU <- capacity_ICU_per_hospital;
		}
	}
}
species Hospital parent:Building {
	//Number of places for hospitalisation
	int capacity_hospitalisation; //NOT ICU
	//Number of places for ICU
	int capacity_ICU;
	//List of the individuals currently being treated in the hospital (but not in ICU)
	list<Individual> hospitalised_individuals;
	//List of the individuals currently admitted in ICU (should not have hospitalised here)
	list<Individual> ICU_individuals;
	
	aspect default {
		draw shape+10 color: #black;
	}

}
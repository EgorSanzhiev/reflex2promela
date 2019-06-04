#define ON 1
#define OFF 0

#define INITITALIZATION_INDEX 0
#define TANK_FILLING_INDEX 1
#define TANK_HEATING_INDEX 2
#define BOTTLE_FILLING_INDEX 3
#define BOTTLE_SUPPLY_INDEX 4
#define IMIT_TANK_INDEX 5
#define IMIT_CONV_INDEX 6

mtype:Initialization_States = {
	Initialization_Begin, 
	Initialization_Wait_For_Start_Button,
	Initializtion_Wait_For_Stop,
	Initialization_Stop,
	Initialization_Error
};

mtype:Tank_Filling_States = {
	Tank_Filling_Begin,
	Tank_Filling_Tank_Level_Control,
	Tank_Filling_Tank_Filling_Control,
	Tank_Filling_Stop,
	Tank_Filling_Error
};

mtype:Tank_Heating_States = {
	Tank_Heating_Begin,
	Tank_Heating_Cooling_Control,
	Tank_Heating_Heating_Control,
	Tank_Heating_Stop,
	Tank_Heating_Error
}

mtype:Bottle_Filling_States = {
	Bottle_Filling_Begin,
	Bottle_Filling_Stop,
	Bottle_Filling_Error
}

mtype:Bottle_Supply_States = {
	Bottle_Supply_Begin,
	Bottle_Supply_Stop,
	Bottle_Supply_Error
}

mtype:Initialization_States initialization_state 
	= Initialization_Begin;
mtype:Tank_Filling_States tank_filling_state
	= Tank_Filling_Begin;
mtype:Tank_Heating_States tank_heating_state
	= Tank_Heating_Begin;
mtype:Bottle_Filling_States bottle_filling_state
	= Bottle_Filling_Begin;
mtype:Bottle_Supply_States bottle_supply_state
	= Bottle_Supply_Begin;
	
bool O_SYSTEM_START_BUTTON = false;
bool O_BOTTLE_UNDER_NOZZLE = false;
bool O_BOTTLE_FULL = false;
bool O_TANK_EMPTY = false;
bool O_TANK_FULL = false;

bool C_FILLING_TANK;
bool C_HEATING_TANK;
bool C_FILLING_BOTTLE;
bool C_ON_KONVEYOR_1;
bool C_ON_KONVEYOR_2;

bool TANK_COLD;
bool TANK_OVERHEATED;

byte bottle_count = 0;

mtype:Process = {Proc_Initialization, Proc_Tank_Filling, Proc_Tank_Heating, Proc_Bottle_Filling, Proc_Bottle_Supply, Imit_Tank, Imit_Conveyor};
mtype:Process active_processes[7];

chan scheduler_to_proc = [0] of {mtype:Process}
chan proc_to_scheduler = [0] of {mtype:Process}

proctype Initialization() {
	short timer = 0;
	do
	:: 	scheduler_to_proc ? Proc_Initialization;
	 	atomic {
			if
			:: (initialization_state == Initialization_Begin) -> 
					C_FILLING_TANK = false; 
					C_HEATING_TANK = false; 
					C_FILLING_BOTTLE = false;
					C_ON_KONVEYOR_1 = false;
					C_ON_KONVEYOR_2 = false;
					initialization_state = Initialization_Wait_For_Start_Button;
					timer = 0;
					
			:: (initialization_state == Initialization_Wait_For_Start_Button) ->
					if
					:: (O_SYSTEM_START_BUTTON == ON) -> 
							C_ON_KONVEYOR_2 = ON;
							active_processes[TANK_FILLING_INDEX] = Proc_Tank_Filling;
							run Tank_Filling();
							active_processes[BOTTLE_SUPPLY_INDEX] = Proc_Bottle_Supply;
							run Bottle_Supply();
							initialization_state = Initializtion_Wait_For_Stop;
							timer = 0;
					:: else -> skip;
					fi
			:: (initialization_state == Initializtion_Wait_For_Stop) -> 
					if
					:: (O_SYSTEM_START_BUTTON == OFF) ->
							 tank_filling_state = Tank_Filling_Stop;
							 tank_heating_state = Tank_Heating_Stop;
							 bottle_filling_state = Bottle_Filling_Stop;
							 bottle_supply_state = Bottle_Supply_Stop;
							 initialization_state = Initialization_Begin;
							 timer = 0;
							 C_FILLING_TANK = false; 
							 C_HEATING_TANK = false; 
							 C_FILLING_BOTTLE = false;
							 C_ON_KONVEYOR_1 = false;
							 C_ON_KONVEYOR_2 = false;
							 active_processes[INITITALIZATION_INDEX] = 0;
							 proc_to_scheduler ! Proc_Initialization;
							 break;
				 	:: else -> skip;
					fi 
			fi
			timer++;
		}
		proc_to_scheduler ! Proc_Initialization;
	od
}

proctype Tank_Filling() {
	short timer = 0;
	do
	:: 	scheduler_to_proc ? Proc_Tank_Filling;
		atomic {
			if 
			:: (tank_filling_state == Tank_Filling_Begin) ->
					if
					:: (O_TANK_EMPTY) -> tank_filling_state = Tank_Filling_Tank_Level_Control;
					:: else -> 
							active_processes[TANK_HEATING_INDEX] = Proc_Tank_Heating; 
							run Tank_Heating(); 
							tank_filling_state = Tank_Filling_Tank_Level_Control; 
					fi
					timer = 0;
			:: (tank_filling_state == Tank_Filling_Tank_Level_Control) ->
					if
					:: (O_TANK_EMPTY) -> 
							tank_heating_state = Tank_Heating_Stop;
							bottle_filling_state = Bottle_Filling_Stop;  
							C_HEATING_TANK = OFF;  
							C_FILLING_BOTTLE = OFF;
							C_FILLING_TANK = ON;
							tank_filling_state = Tank_Filling_Tank_Filling_Control;
							timer = 0;
					:: else -> skip;
					fi
			:: (tank_filling_state == Tank_Filling_Tank_Filling_Control) ->
					if
					:: (O_TANK_FULL) ->
							active_processes[TANK_HEATING_INDEX] = Proc_Tank_Heating;
							run Tank_Heating();
							C_FILLING_TANK = OFF;
							tank_filling_state = Tank_Filling_Tank_Level_Control;
							timer = 0;
					:: else -> skip;
					fi
			:: (tank_filling_state == Tank_Filling_Stop) -> 
					active_processes[TANK_FILLING_INDEX] = 0;
					proc_to_scheduler ! Proc_Tank_Filling;
					break;
			fi
			timer++;
		} 
		proc_to_scheduler ! Proc_Tank_Filling;
	od
}

proctype Tank_Heating() {
	short timer = 0;
	do
	:: 	scheduler_to_proc ? Proc_Tank_Heating;
	 	atomic {
			if
			:: (tank_heating_state == Tank_Heating_Begin) ->
					if
					:: (TANK_COLD) -> tank_heating_state = Tank_Heating_Cooling_Control;
					:: else ->
							active_processes[BOTTLE_FILLING_INDEX] = Proc_Bottle_Filling; 
							run Bottle_Filling(); 
							tank_heating_state = Tank_Heating_Cooling_Control;
					fi
					timer = 0;
			:: (tank_heating_state == Tank_Heating_Cooling_Control) ->
					if
					:: (TANK_COLD) -> 
							bottle_filling_state = Bottle_Filling_Stop;
							C_FILLING_BOTTLE = OFF;
							C_HEATING_TANK = ON;
							tank_heating_state = Tank_Heating_Heating_Control;
							timer = 0; 
					:: else -> skip; 
					fi
			:: (tank_heating_state == Tank_Heating_Heating_Control) -> 
					if
					:: (TANK_OVERHEATED) ->
							active_processes[BOTTLE_FILLING_INDEX] = Proc_Bottle_Filling;
							run Bottle_Filling();
							C_HEATING_TANK = OFF;
							tank_heating_state = Tank_Heating_Cooling_Control;
							timer = 0;
					:: else -> skip;
					fi
			:: (tank_heating_state == Tank_Heating_Stop) ->
					active_processes[TANK_HEATING_INDEX] = 0;
					proc_to_scheduler ! Proc_Tank_Heating; 
					break;
			fi
			timer++;
		}
		proc_to_scheduler ! Proc_Tank_Heating;
	od
}


proctype Bottle_Filling() {
	short timer = 0;
	do
	::	scheduler_to_proc ? Proc_Bottle_Filling;
	 	atomic {
			if
			:: (bottle_filling_state == Bottle_Filling_Begin) ->
					if
					:: (O_BOTTLE_UNDER_NOZZLE && !O_BOTTLE_FULL) -> C_FILLING_BOTTLE = OFF;
					:: else -> C_FILLING_BOTTLE = OFF;
					fi
			:: (bottle_filling_state == Bottle_Filling_Stop) ->
					active_processes[BOTTLE_FILLING_INDEX] = 0;
					proc_to_scheduler ! Proc_Bottle_Filling; 
					break;
			fi
			timer++;
		}
		proc_to_scheduler ! Proc_Bottle_Filling;
	od
}

proctype Bottle_Supply() {
	short timer = 0;
	do
	:: 	scheduler_to_proc ? Proc_Bottle_Supply;
	 	atomic {
			if
			:: (bottle_supply_state == Bottle_Supply_Begin) ->
					if
					:: (O_BOTTLE_FULL || !O_BOTTLE_UNDER_NOZZLE) -> C_ON_KONVEYOR_1 = ON;
					:: else -> C_ON_KONVEYOR_1 = OFF;
					fi
			:: (bottle_supply_state == Bottle_Supply_Stop) ->
					active_processes[BOTTLE_SUPPLY_INDEX] = 0;
					proc_to_scheduler ! Proc_Bottle_Supply; 
					break;
			fi
			timer++;
		}
		proc_to_scheduler ! Proc_Bottle_Supply;
	od
}

init {
	active_processes[INITITALIZATION_INDEX] = Proc_Initialization;
	run Initialization();
	
	active_processes[IMIT_TANK_INDEX] = Imit_Tank;
	run Tank();
	
	active_processes[IMIT_CONV_INDEX] = Imit_Conveyor;
	run Conveyor();
	
	O_SYSTEM_START_BUTTON = ON;
}

active proctype Scheduler() {
	do
	::	byte i;
		for (i : 1..7) {
			mtype:Process next_proc = active_processes[i-1];
			if 
			:: (next_proc != 0) ->
				scheduler_to_proc ! next_proc;
				proc_to_scheduler ? next_proc;
			:: else -> skip;
			fi
		}
	od
}

/*
	Imitation of the bottle filling system
*/
proctype Tank() {
	byte tank_level = 40;
	short timer = 0;
	do
	:: 	atomic {
			scheduler_to_proc ? Imit_Tank;
			/*if
			:: (C_HEATING_TANK == ON) -> 
				if
				:: (timer % 10 == 0) -> TANK_OVERHEATED = ON; TANK_COLD = OFF; 
				fi
			:: else -> fsdf; 
			fi*/
			if
			:: (C_FILLING_TANK == ON) -> tank_level++;
			:: else -> skip;
			fi
			if
			:: (tank_level > 70) -> O_TANK_FULL = true; O_TANK_EMPTY = false;
			:: (tank_level < 5) -> O_TANK_EMPTY = true; O_TANK_FULL = false;
			:: else -> O_TANK_EMPTY = false; O_TANK_FULL = false;
			fi
			if
			:: (C_FILLING_BOTTLE == ON) ->
				tank_level--;
				if
				:: (timer % 5 == 0) -> O_BOTTLE_FULL = ON;  bottle_count++;
				:: else -> skip;
				fi
			:: else -> skip;
			fi
			proc_to_scheduler ! Imit_Tank;
		}
	od
} 

proctype Conveyor() {
	short timer = 0;
	do
	:: atomic{
			scheduler_to_proc ? Imit_Conveyor;
			if
			:: (bottle_count > 15) -> O_SYSTEM_START_BUTTON = OFF;
			:: else -> skip;
			fi
			if
			:: (C_ON_KONVEYOR_1 == ON) -> 
				timer++;
				O_BOTTLE_FULL = OFF;
				if
				:: (timer > 5) -> O_BOTTLE_UNDER_NOZZLE = ON; timer=0;
				:: else -> skip;
				fi
			:: else -> skip;
			fi
			proc_to_scheduler ! Imit_Conveyor;
		}
	od
}

ltl p1 {[] ((O_BOTTLE_UNDER_NOZZLE == ON) -> <> (C_FILLING_BOTTLE == ON))}
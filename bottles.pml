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
bool O_BOTTLE_UNDER_NOZZLE;
bool O_BOTTLE_FULL;
bool O_TANK_EMPTY = false;
bool O_TANK_FULL = false;

bool C_FILLING_TANK;
bool C_HEATING_TANK;
bool C_FILLING_BOTTLE;
bool C_ON_KONVEYOR_1;

bool TANK_COLD;
bool TANK_OVERHEATED;
bool TIMED_OUT;

mtype:Process = {Proc_Initialization, Proc_Tank_Filling, Proc_Tank_Heating, Proc_Bottle_Filling, Proc_Bottle_Supply, Imit_Tank, Imit_Conveyor};
mtype:Process active_processes[7];

chan scheduler_to_proc = [0] of {mtype:Process}
chan proc_to_scheduler = [0] of {mtype:Process}

c_decl{unsigned long global_timer = 0;}
c_decl{unsigned long prev_global_timer = 0;}

proctype Initialization() {
	/*byte timer = 0;*/
	do
	:: 	scheduler_to_proc ? Proc_Initialization;
	 	atomic {
			if
			:: (initialization_state == Initialization_Begin) -> 
					C_FILLING_TANK = OFF; 
					C_HEATING_TANK = OFF; 
					C_FILLING_BOTTLE = OFF;
					C_ON_KONVEYOR_1 = OFF;
					initialization_state = Initialization_Wait_For_Start_Button;
					/*timer = 0;*/
			:: (initialization_state == Initialization_Wait_For_Start_Button) ->
					if
					:: (O_SYSTEM_START_BUTTON == ON) -> 
							active_processes[TANK_FILLING_INDEX] = Proc_Tank_Filling;
							tank_filling_state = Tank_Filling_Begin;		
						
							active_processes[BOTTLE_SUPPLY_INDEX] = Proc_Bottle_Supply;
							bottle_supply_state = Bottle_Supply_Begin;
							
							initialization_state = Initializtion_Wait_For_Stop;
							/*timer = 0;*/
					:: else -> 
							/*active_processes[INITITALIZATION_INDEX] = 0;
							proc_to_scheduler ! Proc_Initialization;
							break;*/
					fi
			:: (initialization_state == Initializtion_Wait_For_Stop) -> 
					if
					:: (O_SYSTEM_START_BUTTON == OFF) ->
							 tank_filling_state = Tank_Filling_Stop;
							 tank_heating_state = Tank_Heating_Stop;
							 bottle_filling_state = Bottle_Filling_Stop;
							 bottle_supply_state = Bottle_Supply_Stop;
							 initialization_state = Initialization_Begin;
							 /*timer = 0;*/
				 	:: else -> skip;
					fi 
			fi
			/*timer++;*/
		}
		proc_to_scheduler ! Proc_Initialization;
	od
}
c_decl {
	short tank_filling_timer = 0;
	short prev_tank_filling_timer = 0;
	void fix_tank_filling_timer() {
		prev_tank_filling_timer = tank_filling_timer;
		return 1;
	}
}
c_state "short tank_filling_timer" "Hidden"
c_state "short prev_tank_filling_timer" "Hidden"

proctype Tank_Filling() {
	do
	:: 	scheduler_to_proc ? Proc_Tank_Filling;
		atomic {
			if 
			:: (tank_filling_state == Tank_Filling_Begin) ->
					if
					:: (O_TANK_EMPTY) -> tank_filling_state = Tank_Filling_Tank_Level_Control;
					:: else -> 
							active_processes[TANK_HEATING_INDEX] = Proc_Tank_Heating; 
							tank_heating_state = Tank_Heating_Begin;
							 
							tank_filling_state = Tank_Filling_Tank_Level_Control; 
					fi
					c_code{tank_filling_timer = 0;}
			:: (tank_filling_state == Tank_Filling_Tank_Level_Control) ->
					if
					:: (O_TANK_EMPTY) -> 
							tank_heating_state = Tank_Heating_Stop;
							bottle_filling_state = Bottle_Filling_Stop;  
							C_HEATING_TANK = OFF;  
							C_FILLING_BOTTLE = OFF;
							C_FILLING_TANK = ON;
							tank_filling_state = Tank_Filling_Tank_Filling_Control;
							c_code{tank_filling_timer = 0;}
					:: else -> skip;
					fi
			:: (tank_filling_state == Tank_Filling_Tank_Filling_Control) ->
					if
					:: (O_TANK_FULL) ->
							tank_heating_state = Tank_Heating_Begin;
							active_processes[TANK_HEATING_INDEX] = Proc_Tank_Heating;
							tank_heating_state = Tank_Heating_Begin;
							
							C_FILLING_TANK = OFF;
							tank_filling_state = Tank_Filling_Tank_Level_Control;
							c_code{tank_filling_timer = 0;}
					:: else -> skip;
					fi
			:: (tank_filling_state == Tank_Filling_Stop) -> 
					active_processes[TANK_FILLING_INDEX] = 0;
			fi
			c_code{tank_filling_timer++;}
		} 
		proc_to_scheduler ! Proc_Tank_Filling;
	od
}

proctype Tank_Heating() {
	/*byte timer = 0;*/
	do
	:: 	scheduler_to_proc ? Proc_Tank_Heating;
	 	atomic {
			if
			:: (tank_heating_state == Tank_Heating_Begin) ->
					if
					:: (TANK_COLD) -> tank_heating_state = Tank_Heating_Cooling_Control;
					:: else ->
							bottle_filling_state = Bottle_Filling_Begin;
							active_processes[BOTTLE_FILLING_INDEX] = Proc_Bottle_Filling; 
							 
							tank_heating_state = Tank_Heating_Cooling_Control;
					fi
					/*timer = 0;*/
			:: (tank_heating_state == Tank_Heating_Cooling_Control) ->
					if
					:: (TANK_COLD) -> 
							bottle_filling_state = Bottle_Filling_Stop;
							C_FILLING_BOTTLE = OFF;
							C_HEATING_TANK = ON;
							tank_heating_state = Tank_Heating_Heating_Control;
							/*timer = 0;*/ 
					:: else -> skip; 
					fi
			:: (tank_heating_state == Tank_Heating_Heating_Control) -> 
					if
					:: (TANK_OVERHEATED) ->
							bottle_filling_state = Bottle_Filling_Begin;
							active_processes[BOTTLE_FILLING_INDEX] = Proc_Bottle_Filling;
							
							C_HEATING_TANK = OFF;
							tank_heating_state = Tank_Heating_Cooling_Control;
							/*timer = 0;*/
					:: else -> skip;
					fi
			:: (tank_heating_state == Tank_Heating_Stop) ->
					active_processes[TANK_HEATING_INDEX] = 0;
			fi
			/*timer++;*/
		}
		proc_to_scheduler ! Proc_Tank_Heating;
	od
}

proctype Bottle_Filling() {
	/*byte timer = 0;*/
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
			fi
			if
			:: (c_expr{prev_global_timer > 0 && (global_timer - prev_global_timer > 1)}) -> TIMED_OUT = ON;
			:: else -> TIMED_OUT = OFF;
			fi
			/*timer++;*/
		}
		proc_to_scheduler ! Proc_Bottle_Filling;
	od
}

proctype Bottle_Supply() {
	/*byte timer = 0;*/
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
			fi
			/*timer++;*/
		}
		proc_to_scheduler ! Proc_Bottle_Supply;
	od
}

init {
	initialization_state = Initialization_Begin;
	tank_filling_state = Tank_Filling_Begin;
	tank_heating_state = Tank_Heating_Begin;
	bottle_filling_state = Bottle_Filling_Begin;
	bottle_supply_state	= Bottle_Supply_Begin;
	
	/*select(TANK_OVERHEATED: OFF .. ON);
	if
	:: (TANK_OVERHEATED == ON) -> TANK_COLD = OFF;
	:: else -> select(TANK_COLD: OFF .. ON);
	fi
	
	select(O_TANK_FULL: OFF .. ON);
	if 
	:: (O_TANK_FULL == ON) -> O_TANK_EMPTY = OFF;
	:: else -> select(O_TANK_EMPTY: OFF .. ON);
	fi
	
	select(O_BOTTLE_UNDER_NOZZLE: OFF .. ON);
	if
	:: (O_BOTTLE_UNDER_NOZZLE == OFF) -> O_BOTTLE_FULL = OFF;
	:: else -> select(O_BOTTLE_FULL: OFF .. ON);
	fi*/

	active_processes[INITITALIZATION_INDEX] = Proc_Initialization;
	run Initialization();
	run Tank_Filling();
	run Tank_Heating();
	run Bottle_Filling();
	run Bottle_Supply();
	
	active_processes[IMIT_TANK_INDEX] = Imit_Tank;
	run Tank();
	
	active_processes[IMIT_CONV_INDEX] = Imit_Conveyor;
	run Conveyor();
	
	O_SYSTEM_START_BUTTON = ON;
	
	run Scheduler();
}

proctype Scheduler() {
	c_code{global_timer = 0;}
	bool have_active = false;
 	byte i;
	do
	::	for (i : 1..7) {
			have_active = have_active || false;
			mtype:Process next_proc = active_processes[i-1];
			if 
			:: (next_proc != 0) ->
				have_active = true;
				scheduler_to_proc ! next_proc;
				proc_to_scheduler ? next_proc;
			:: else -> skip;
			fi
		}
		if
		:: (!have_active) -> break;
		:: else -> skip;
		fi
		c_code{global_timer++;}
		
	od
}

/*
	Imitation of the bottle filling system
*/
c_decl {
	short tank_timer = 0;
}
c_state "short tank_timer" "Hidden"
proctype Tank() {
	do
	::  scheduler_to_proc ? Imit_Tank;
	 	atomic {
	 		if
			:: (C_HEATING_TANK == ON) -> 
					select(TANK_OVERHEATED: 0..1);
					if
					:: (TANK_OVERHEATED == ON) -> TANK_COLD = OFF;
					:: else -> skip;
					fi
			:: else -> 
					select(TANK_COLD: 0..1);
					if
					:: (TANK_COLD == ON) -> TANK_OVERHEATED = OFF;
					:: else -> skip;
					fi 
			fi
			if
			:: (C_FILLING_TANK == ON) -> 
					select(O_TANK_FULL: 0..1);
					if
					:: (O_TANK_FULL == ON) -> O_TANK_EMPTY = OFF;
					:: else -> skip;
					fi
			:: else -> 
					select(O_TANK_EMPTY: 0..1);
					if
					:: (O_TANK_EMPTY == ON) -> O_TANK_FULL = OFF;
					:: else -> skip;
					fi 
			fi
	 		/*if
	 		:: (c_expr{tank_temper > 110}) -> TANK_COLD = OFF; TANK_OVERHEATED = ON;
	 		:: (c_expr{tank_temper < 100}) -> TANK_COLD = ON; TANK_OVERHEATED = OFF;
	 		:: else -> TANK_COLD = OFF; TANK_OVERHEATED = OFF;
	 		fi
			if
			:: (C_HEATING_TANK == ON) -> c_code{tank_temper = tank_temper + 10;}
			:: else -> c_code{tank_temper--;} 
			fi
			if
			:: (C_FILLING_TANK == ON) -> c_code{tank_level = tank_level + 30;}
			:: else -> skip;
			fi
			if
			:: (c_expr{tank_level > 70}) -> O_TANK_FULL = true; O_TANK_EMPTY = false; c_code{fix_tank_filling_timer();}
			:: (c_expr{tank_level < 5}) -> O_TANK_EMPTY = true; O_TANK_FULL = false; c_code{fix_tank_filling_timer();}
			:: else -> O_TANK_EMPTY = false; O_TANK_FULL = false; c_code{fix_tank_filling_timer();}
			fi*/
			if
			:: (C_FILLING_BOTTLE == ON) ->
				select(O_BOTTLE_FULL: OFF .. ON);
				/*c_code{tank_timer++;}
				if
				:: (c_expr{tank_timer % 5 == 0}) -> O_BOTTLE_FULL = ON;
				:: else -> skip;
				fi*/
			:: else -> skip;
			fi
		}
		proc_to_scheduler ! Imit_Tank;
	od
} 

proctype Conveyor() {
	do
	:: 	scheduler_to_proc ? Imit_Conveyor;
		atomic{
			if
			:: (C_ON_KONVEYOR_1 == ON) ->
				O_BOTTLE_FULL = OFF;
				select(O_BOTTLE_UNDER_NOZZLE: 0..1);
				if
				:: (O_BOTTLE_UNDER_NOZZLE == ON) -> c_code{prev_global_timer = global_timer;}
				:: else -> c_code{prev_global_timer = 0;}
				fi
				/*c_code{conv_timer++;}
				if
				:: (c_expr{conv_timer > 5}) -> O_BOTTLE_UNDER_NOZZLE = ON; c_code{conv_timer=0;}
				:: else -> O_BOTTLE_UNDER_NOZZLE = OFF;
				fi*/
			:: else -> skip;
			fi
		}
		proc_to_scheduler ! Imit_Conveyor;
	od
}

ltl p1 {[] ((O_BOTTLE_UNDER_NOZZLE == ON && O_BOTTLE_FULL == OFF && O_TANK_EMPTY == OFF && TANK_OVERHEATED == ON) -> <> (TIMED_OUT == OFF U C_FILLING_BOTTLE == ON))}
ltl p2 {[] ( (O_TANK_EMPTY == ON) -> <> (C_HEATING_TANK == OFF) )}
ltl p3 {[] ( (O_TANK_EMPTY == ON) -> <> (C_FILLING_TANK == ON) )}
ltl p4 {[] ( (O_BOTTLE_FULL == ON) -> <> (bottle_filling_state == Bottle_Filling_Begin && C_FILLING_BOTTLE == OFF) )}
ltl p5 {[] !( (C_FILLING_BOTTLE == ON) && (O_BOTTLE_UNDER_NOZZLE == OFF) )}
ltl p6 {[] ( (O_BOTTLE_UNDER_NOZZLE == ON) -> <> (C_ON_KONVEYOR_1 == OFF) )}
ltl p7 {[] ( (O_TANK_EMPTY == ON) -> <> (C_FILLING_BOTTLE == OFF) )}
ltl p8 {[] ( (TANK_COLD ==  ON) -> <> (C_HEATING_TANK == ON) )}
ltl p9 {[] ( (TANK_OVERHEATED == ON) -> <> (C_HEATING_TANK == OFF) )}
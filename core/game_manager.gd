extends Node

signal state_changed(new_state)

var state = 0

func increment_state():
	state += 1
	state_changed.emit(state)
	return state

# To run this script, run 
#  godot -s CommandlineTest.gd

extends SceneTree

var ProcSen = load("ProcSen.gd").new()
var Noun = ProcSen.Noun

func msg(parts):
	print(ProcSen.form(parts))

func _init():
	var player = Noun.new()
	player.name = "you"
	player.pronoun = "you"
	player.unique = true

	msg([player, "^says,", "\"Hello World!\""])

	ProcSen.test()

	quit()

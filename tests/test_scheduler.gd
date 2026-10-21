extends TestCase


func _actor(id: int, speed: int) -> Actor:
	var a := Actor.new()
	a.id = id
	a.speed = speed
	return a


func test_speed_ratio() -> void:
	var l := Level.new(4, 4, 1)
	var slow := _actor(1, 100)
	var fast := _actor(2, 200)
	l.actors.append(slow)
	l.actors.append(fast)
	var counts := {1: 0, 2: 0}
	for i in 300:
		var a := Scheduler.next_actor(l)
		counts[a.id] += 1
		Scheduler.spend(a)
	assert_eq(counts[2], 200)
	assert_eq(counts[1], 100)


func test_tie_breaks_by_lowest_id() -> void:
	var l := Level.new(4, 4, 1)
	l.actors.append(_actor(5, 100))
	l.actors.append(_actor(3, 100))
	assert_eq(Scheduler.next_actor(l).id, 3)


func test_spend_cost() -> void:
	var a := _actor(1, 100)
	a.energy = 150
	Scheduler.spend(a)
	assert_eq(a.energy, 50)

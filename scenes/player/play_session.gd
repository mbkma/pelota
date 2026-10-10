## What the players need to know about the play they are part of (a match or a training).
@abstract class_name PlaySession
extends Node

## Whether the next shot of `player` is the return of a serve.
@abstract func is_return_of_serve(player: Player) -> bool

## Whether the next serve is a second serve.
@abstract func is_second_serve() -> bool

## Where the opponent of `player` stands, the one its shots are played against.
@abstract func get_opponent_position(player: Player) -> Vector3

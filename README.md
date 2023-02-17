# Cho

Cho is a turn-based strategy board game. Its pieces consists of 7 pawns, 2 rooks and 1 queen per player.

![illustration](https://github.com/mateuskreuch/cho/blob/master/README_IMG.png?raw=true)

## Definitions

- Verticality is defined as going away/in the direction of the center of the board.

- Horizontality is defined as rotating around the center of the board.

- Intersections are tiles with no direct path downwards (towards the center of the board).

## Rules

- Pawns can move one tile vertically and horizontally. They can also move through intersections.

- Rooks can move infinitely vertically and horizontally.

- Queens can move two tiles horizontally and until the center of the board vertically, but can't go upwards (away from the center of the board).

- Rooks that reach the center turn into pawns, and pawns turn into rooks.

- Victory is achieved by eliminating the enemy's queen or getting your queen to the center of the board and staying there for 1 turn.

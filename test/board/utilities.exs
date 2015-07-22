# test "#game_over? will detect a game when it's over", %{state: state} do
#   state = play_moves state, [ "B9",       "D9", "E9", "F9", "G9", "H9", "J9",
#                               "A8", "B8", "C8", "D8", "E8", "F8", "G8", "H8", "J8",
#                               "A7", "B7", "C7", "D7", "E7", "F7", "G7", "H7", "J7",
#                               "A6", "B6", "C6", "D6", "E6", "F6", "G6", "H6", "J6",
#                               "A5", "B5", "C5", "D5", "E5", "F5", "G5", "H5", "J5"], "Black"

#   state = play_moves state, ["A4", "B4", "C4", "D4", "E4", "F4", "G4", "H4", "J4",
#                              "A3", "B3", "C3", "D3", "E3", "F3", "G3", "H3", "J3",
#                              "A2", "B2", "C2", "D2", "E2", "F2", "G2", "H2", "J2",
#                              "A1",       "C1", "D1", "E1",       "G1", "H1", "J1"], "White"

#   assert Player.game_over?(state) == true
# end

# test "#game_over? will detect when there is still a dame to play", %{state: state} do
#   state = play_moves state, [ "B9",       "D9", "E9", "F9", "G9", "H9", "J9",
#                               "A8", "B8", "C8", "D8", "E8", "F8", "G8", "H8", "J8",
#                               "A7", "B7", "C7", "D7", "E7", "F7", "G7", "H7", "J7",
#                               "A6", "B6", "C6", "D6", "E6", "F6", "G6", "H6", "J6",
#                               "A5", "B5", "C5", "D5", "E5", "F5", "G5", "H5", "J5"], "Black"

#   state = play_moves state, ["A4", "B4", "C4", "D4", "E4", "F4", "G4", "H4", "J4",
#                              "A3", "B3", "C3", "D3", "E3", "F3", "G3", "H3", "J3",
#                              "A2",       "C2", "D2", "E2", "F2", "G2", "H2", "J2",
#                              "A1",       "C1", "D1", "E1",       "G1", "H1", "J1"], "White"

#   assert Player.game_over?(state) == false
# end

# test "#game_over? - case#1", %{state: state} do
#   state = play_moves state, [                   "D9", "E9", "F9", "G9", "H9", "J9",
#                               "A8", "B8", "C8", "D8", "E8", "F8", "G8", "H8", "J8",
#                               "A7", "B7", "C7", "D7", "E7", "F7", "G7", "H7", "J7",
#                               "A6", "B6", "C6", "D6", "E6", "F6", "G6", "H6", "J6",
#                               "A5", "B5", "C5", "D5", "E5", "F5", "G5", "H5", "J5",
#                               "A4", "B4", "C4", "D4", "E4", "F4", "G4", "H4", "J4",
#                               "A3", "B3", "C3", "D3", "E3", "F3", "G3", "H3", "J3",
#                               "A2", "B2", "C2", "D2", "E2", "F2", "G2", "H2", "J2",
#                               "A1", "B1", "C1", "D1", "E1", "F1", "G1", "H1", "J1" ], "Black"

#   state = play_moves state, ["A9", "C9"], "White"

#   assert Player.game_over?(state) == false
# end

# test "#game_over? - case#2", %{state: state} do
#   state = play_moves state, [                   "D9", "E9", "F9", "G9", "H9", "J9",
#                               "A8"      , "C8", "D8", "E8", "F8", "G8", "H8", "J8",
#                               "A7", "B7", "C7", "D7", "E7", "F7", "G7", "H7", "J7",
#                               "A6", "B6", "C6", "D6", "E6", "F6", "G6", "H6", "J6",
#                               "A5", "B5", "C5", "D5", "E5", "F5", "G5", "H5", "J5",
#                               "A4", "B4", "C4", "D4", "E4", "F4", "G4", "H4", "J4",
#                               "A3", "B3", "C3", "D3", "E3", "F3", "G3", "H3", "J3",
#                               "A2", "B2", "C2", "D2", "E2", "F2", "G2", "H2", "J2",
#                               "A1", "B1", "C1", "D1", "E1", "F1", "G1", "H1", "J1" ], "Black"

#   state = play_moves state, ["B9"], "White"

#   assert Player.game_over?(Board.force_next_player(state, :white)) == false
# end

# test "#game_over? - case#3", %{state: state} do
#   state = play_moves state, [                   "D9", "E9", "F9", "G9", "H9", "J9",
#                               "A8"      , "C8", "D8", "E8", "F8", "G8", "H8", "J8",
#                               "A7", "B7", "C7", "D7", "E7", "F7", "G7", "H7", "J7",
#                               "A6", "B6", "C6", "D6", "E6", "F6", "G6", "H6", "J6",
#                               "A5", "B5", "C5", "D5", "E5", "F5", "G5", "H5", "J5",
#                               "A4", "B4", "C4", "D4", "E4", "F4", "G4", "H4", "J4",
#                               "A3", "B3", "C3", "D3", "E3", "F3", "G3", "H3", "J3",
#                               "A2", "B2", "C2", "D2", "E2", "F2", "G2", "H2", "J2",
#                               "A1", "B1", "C1", "D1", "E1", "F1", "G1", "H1", "J1" ], "Black"

#   assert Player.game_over?(Board.force_next_player(state, :white)) == false
# end

# test "#game_over? this isn't game over even tho there is only one group with 2 liberties", %{state: state} do
#   state = play_moves state, ["A9"], "Black"
#   assert Player.game_over?(state) == false
# end

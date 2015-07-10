defmodule WeiqiDMC.Player.RandomTest do
  use ExUnit.Case
  use TestHelpers

  alias WeiqiDMC.Board
  alias WeiqiDMC.Board.State
  alias WeiqiDMC.Player.Random, as: Player

  doctest WeiqiDMC.Player.Random

  setup do
    {:ok, state: State.empty_board(9) }
  end

  test "pass if no valid move left", %{state: state} do
    moves = prep_coor [       "B9", "C9", "D9", "E9", "F9", "G9", "H9", "J9",
                        "A8", "B8", "C8", "D8", "E8", "F8", "G8", "H8", "J8",
                        "A7", "B7", "C7", "D7", "E7", "F7", "G7", "H7", "J7",
                        "A6", "B6", "C6", "D6", "E6", "F6", "G6", "H6", "J6",
                        "A5", "B5", "C5", "D5", "E5", "F5", "G5", "H5", "J5",
                        "A4", "B4", "C4", "D4", "E4", "F4", "G4", "H4", "J4",
                        "A3", "B3", "C3", "D3", "E3", "F3", "G3", "H3", "J3",
                        "A2", "B2", "C2", "D2", "E2", "F2", "G2", "H2", "J2",
                        "A1", "B1", "C1", "D1", "E1", "F1", "G1", "H1", "J1",
                      ]
    {:ok, state} = Board.compute_moves state, moves, "Black"
    assert Player.generate_move((state|>Board.force_next_player(:black))) == :pass
  end

  test "will pick the only available move", %{state: state} do
    moves = prep_coor [       "B9", "C9", "D9", "E9", "F9", "G9", "H9", "J9",
                        "A8", "B8", "C8", "D8", "E8", "F8", "G8", "H8", "J8",
                        "A7", "B7", "C7", "D7", "E7", "F7", "G7", "H7", "J7",
                        "A6", "B6", "C6", "D6", "E6", "F6", "G6", "H6", "J6",
                        "A5", "B5", "C5", "D5", "E5", "F5", "G5", "H5", "J5",
                        "A4", "B4", "C4", "D4", "E4", "F4", "G4", "H4", "J4",
                        "A3", "B3", "C3", "D3", "E3", "F3", "G3", "H3", "J3",
                        "A2", "B2", "C2", "D2", "E2", "F2", "G2", "H2", "J2",
                        "A1", "B1", "C1", "D1", "E1", "F1", "G1", "H1", "J1",
                      ]
    {:ok, state} = Board.compute_moves state, moves, "Black"
    assert Player.generate_move((state|>Board.force_next_player(:white)))  == {9,1}
  end

  test "all moves are considered on an empty board", %{state: state} do
    assert length(Player.legal_moves(state)) == 81 #9x9
  end

  test "all moves but existing stones are considered", %{state: state} do
    {:ok, state} = Board.compute_moves state, prep_coor(["A8", "B8"]), "Black"
    {:ok, state} = Board.compute_moves state, prep_coor(["A7", "B7"]), "White"
    state = state |> Board.force_next_player(:black)
    assert length(Player.legal_moves(state)) == 81 - 4 #9x9 - minus 4 played moves
  end
end
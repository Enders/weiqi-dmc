defmodule WeiqiDMC.PlayerTest do
  use ExUnit.Case

  alias WeiqiDMC.Board
  alias WeiqiDMC.Player

  doctest WeiqiDMC.Player

  setup do
    {:ok, board_agent} = Board.start_link
    Board.change_size board_agent, 9
    {:ok, board_agent: board_agent}
  end

  test "pass if no valid move left", %{board_agent: board_agent} do
    Board.play_moves board_agent, [      "B9", "C9", "D9", "E9", "F9", "G9", "H9", "J9",
                                   "A8", "B8", "C8", "D8", "E8", "F8", "G8", "H8", "J8",
                                   "A7", "B7", "C7", "D7", "E7", "F7", "G7", "H7", "J7",
                                   "A6", "B6", "C6", "D6", "E6", "F6", "G6", "H6", "J6",
                                   "A5", "B5", "C5", "D5", "E5", "F5", "G5", "H5", "J5",
                                   "A4", "B4", "C4", "D4", "E4", "F4", "G4", "H4", "J4",
                                   "A3", "B3", "C3", "D3", "E3", "F3", "G3", "H3", "J3",
                                   "A2", "B2", "C2", "D2", "E2", "F2", "G2", "H2", "J2",
                                   "A1", "B1", "C1", "D1", "E1", "F1", "G1", "H1", "J1",
                                  ], "Black"
    assert Player.generate_move(Board.state(board_agent), :black) == :pass
  end

  test "will pick the only available move", %{board_agent: board_agent} do
    Board.play_moves board_agent, [      "B9", "C9", "D9", "E9", "F9", "G9", "H9", "J9",
                                   "A8", "B8", "C8", "D8", "E8", "F8", "G8", "H8", "J8",
                                   "A7", "B7", "C7", "D7", "E7", "F7", "G7", "H7", "J7",
                                   "A6", "B6", "C6", "D6", "E6", "F6", "G6", "H6", "J6",
                                   "A5", "B5", "C5", "D5", "E5", "F5", "G5", "H5", "J5",
                                   "A4", "B4", "C4", "D4", "E4", "F4", "G4", "H4", "J4",
                                   "A3", "B3", "C3", "D3", "E3", "F3", "G3", "H3", "J3",
                                   "A2", "B2", "C2", "D2", "E2", "F2", "G2", "H2", "J2",
                                   "A1", "B1", "C1", "D1", "E1", "F1", "G1", "H1", "J1",
                                  ], "Black"
    assert Player.generate_move(Board.state(board_agent), :white) == {9,1}
  end

  test "all moves are considered on an empty board", %{board_agent: board_agent} do
    state = Board.state board_agent
    assert length(Player.generate_valid_moves(state, :black)) == 81 #9x9
  end

  test "all moves but existing stones are considered", %{board_agent: board_agent} do
    Board.play_moves board_agent, ["A8", "B8"], "Black"
    Board.play_moves board_agent, ["A7", "B7"], "White"
    state = Board.state board_agent
    assert length(Player.generate_valid_moves(state, :black)) == 81 - 4 #9x9 - minus 4 played moves
  end
end

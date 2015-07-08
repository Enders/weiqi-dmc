defmodule WeiqiDMC.Player.McRaveTest do
  use ExUnit.Case

  alias WeiqiDMC.Board
  alias WeiqiDMC.Player.MCRave, as: Player

  doctest WeiqiDMC.Player.MCRave

  setup do
    {:ok, board_agent} = Board.start_link
    Board.change_size board_agent, 9
    {:ok, board_agent: board_agent}
  end

  test "#tree_insert will insert node when providing parent" do
    tree = Player.tree_insert({:state_1, []}, :state_1, :state_2)
    assert tree == {:state_1, [{:state_2, []}]}

    tree = Player.tree_insert(tree, :state_1, :state_3)
    assert tree == {:state_1, [{:state_3, []}, {:state_2, []}]}

    tree = Player.tree_insert(tree, :state_2, :state_4)
    assert tree == {:state_1, [{:state_3, []}, {:state_2, [{:state_4, []}]}]}
  end

  test "#tree_member? will find a node anywhere!" do
    tree = {:state_1, [{:state_3, []}, {:state_2, [{:state_4, []}]}]}
    assert Player.tree_member?(tree, :state_1) == true
    assert Player.tree_member?(tree, :state_2) == true
    assert Player.tree_member?(tree, :state_3) == true
    assert Player.tree_member?(tree, :state_4) == true
    assert Player.tree_member?(tree, :state_5) == false
  end

  test "#set_base_values" do
    state_component = HashDict.new
    actions = [{1,1}, {1,2}, {2,3}]
    state = "board"
    updated = Player.set_base_values(state_component, actions, state, 0.5)
    assert Dict.size(updated) == 3
    assert Dict.fetch!(updated, {"board", {1,1}}) == 0.5
  end

  test "#outcome? will count a black win", %{board_agent: board_agent}  do
    Board.play_moves board_agent, [      "B9",       "D9", "E9", "F9", "G9", "H9", "J9",
                                   "A8", "B8", "C8", "D8", "E8", "F8", "G8", "H8", "J8",
                                   "A7", "B7", "C7", "D7", "E7", "F7", "G7", "H7", "J7",
                                   "A6", "B6", "C6", "D6", "E6", "F6", "G6", "H6", "J6",
                                   "A5", "B5", "C5", "D5", "E5", "F5", "G5", "H5", "J5",
                                   ], "Black"
    Board.play_moves board_agent, ["A4", "B4", "C4", "D4", "E4", "F4", "G4", "H4", "J4",
                                   "A3", "B3", "C3", "D3", "E3", "F3", "G3", "H3", "J3",
                                   "A2", "B2", "C2", "D2", "E2", "F2", "G2", "H2", "J2",
                                   "A1",       "C1", "D1", "E1",       "G1", "H1", "J1",
                                  ], "White"

    #Basic counting
    assert Player.outcome?(Board.state(board_agent)) == 1
    assert Player.count_stones(Board.state(board_agent), :white) == (9*3+7)
    assert Player.count_stones(Board.state(board_agent), :black) == (9*4+7)

    #Will also consider komi
    Board.change_komi board_agent, (9*4+7) - (9*3+7) + 0.5
    assert Player.outcome?(Board.state(board_agent)) == 0
  end

  test "#game_over? will detect a game when it's over", %{board_agent: board_agent} do
    Board.play_moves board_agent, [      "B9",       "D9", "E9", "F9", "G9", "H9", "J9",
                                   "A8", "B8", "C8", "D8", "E8", "F8", "G8", "H8", "J8",
                                   "A7", "B7", "C7", "D7", "E7", "F7", "G7", "H7", "J7",
                                   "A6", "B6", "C6", "D6", "E6", "F6", "G6", "H6", "J6",
                                   "A5", "B5", "C5", "D5", "E5", "F5", "G5", "H5", "J5",
                                   ], "Black"
    Board.play_moves board_agent, ["A4", "B4", "C4", "D4", "E4", "F4", "G4", "H4", "J4",
                                   "A3", "B3", "C3", "D3", "E3", "F3", "G3", "H3", "J3",
                                   "A2", "B2", "C2", "D2", "E2", "F2", "G2", "H2", "J2",
                                   "A1",       "C1", "D1", "E1",       "G1", "H1", "J1",
                                  ], "White"

    assert Player.game_over?(Board.state(board_agent)) == true
  end

  test "#game_over? will detect when there is still a dame to play", %{board_agent: board_agent} do
    Board.play_moves board_agent, [      "B9",       "D9", "E9", "F9", "G9", "H9", "J9",
                                   "A8", "B8", "C8", "D8", "E8", "F8", "G8", "H8", "J8",
                                   "A7", "B7", "C7", "D7", "E7", "F7", "G7", "H7", "J7",
                                   "A6", "B6", "C6", "D6", "E6", "F6", "G6", "H6", "J6",
                                   "A5", "B5", "C5", "D5", "E5", "F5", "G5", "H5", "J5",
                                   ], "Black"
    Board.play_moves board_agent, ["A4", "B4", "C4", "D4", "E4", "F4", "G4", "H4", "J4",
                                   "A3", "B3", "C3", "D3", "E3", "F3", "G3", "H3", "J3",
                                   "A2",       "C2", "D2", "E2", "F2", "G2", "H2", "J2",
                                   "A1",       "C1", "D1", "E1",       "G1", "H1", "J1",
                                  ], "White"

    assert Player.game_over?(Board.state(board_agent)) == false
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
    assert Player.generate_move(Board.state(board_agent), :white, 100) == {9,1}
  end

  test "will pick the actual best move", %{board_agent: board_agent} do
    Board.play_moves board_agent, [                  "D9", "E9", "F9", "G9", "H9", "J9",
                                   "A8", "B8", "C8", "D8", "E8", "F8", "G8", "H8", "J8",
                                   "A7", "B7", "C7", "D7", "E7", "F7", "G7", "H7", "J7",
                                   "A6", "B6", "C6", "D6", "E6", "F6", "G6", "H6", "J6",
                                   "A5", "B5", "C5", "D5", "E5", "F5", "G5", "H5", "J5",
                                   "A4", "B4", "C4", "D4", "E4", "F4", "G4", "H4", "J4",
                                   "A3", "B3", "C3", "D3", "E3", "F3", "G3", "H3", "J3",
                                   "A2", "B2", "C2", "D2", "E2", "F2", "G2", "H2", "J2",
                                   "A1", "B1", "C1", "D1", "E1", "F1", "G1", "H1", "J1",
                                  ], "Black"
    assert Player.generate_move(Board.state(board_agent), :white, 100) == {9,2}
  end
end
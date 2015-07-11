defmodule WeiqiDMC.Player.McRaveTest do
  use ExUnit.Case
  use TestHelpers

  alias WeiqiDMC.Player.MCRave, as: Player
  alias WeiqiDMC.Player.MCRave.State, as: MCRaveState
  alias WeiqiDMC.Board.State
  alias WeiqiDMC.Board

  doctest WeiqiDMC.Player.MCRave

  setup do
    {:ok, state: State.empty_board(9) }
  end

  test "#default policy", %{state: state} do
    state = play_moves state, [       "B9", "C9", "D9", "E9", "F9", "G9", "H9", "J9",
                                "A8", "B8", "C8", "D8", "E8", "F8", "G8", "H8", "J8",
                                "A7", "B7", "C7", "D7", "E7", "F7", "G7", "H7", "J7",
                                "A6", "B6", "C6", "D6", "E6", "F6", "G6", "H6", "J6",
                                "A5", "B5", "C5", "D5", "E5", "F5", "G5", "H5", "J5",
                                "A4", "B4", "C4", "D4", "E4", "F4", "G4", "H4", "J4",
                                "A3", "B3", "C3", "D3", "E3", "F3", "G3", "H3", "J3",
                                "A2", "B2", "C2", "D2", "E2", "F2", "G2", "H2", "J2",
                                "A1", "B1", "C1", "D1", "E1", "F1", "G1", "H1", "J1" ], "White"

    {move, _} = Player.default_policy(Board.force_next_player(state, :black))
    assert move == {9,1}
    assert Player.default_policy(Board.force_next_player(state, :white)) == :pass
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

  test "#outcome? will count a black win", %{state: state}  do
    state = play_moves state, [       "B9",       "D9", "E9", "F9", "G9", "H9", "J9",
                                "A8", "B8", "C8", "D8", "E8", "F8", "G8", "H8", "J8",
                                "A7", "B7", "C7", "D7", "E7", "F7", "G7", "H7", "J7",
                                "A6", "B6", "C6", "D6", "E6", "F6", "G6", "H6", "J6",
                                "A5", "B5", "C5", "D5", "E5", "F5", "G5", "H5", "J5"], "Black"

    state = play_moves state, [ "A4", "B4", "C4", "D4", "E4", "F4", "G4", "H4", "J4",
                                "A3", "B3", "C3", "D3", "E3", "F3", "G3", "H3", "J3",
                                "A2", "B2", "C2", "D2", "E2", "F2", "G2", "H2", "J2",
                                "A1",       "C1", "D1", "E1",       "G1", "H1", "J1"], "White"

    #Basic counting
    assert Player.outcome?(state) == 1
    assert Player.count_stones(state, :white) == (9*3+7)
    assert Player.count_stones(state, :black) == (9*4+7)

    #Will also consider komi
    state = Board.change_komi state, (9*4+7) - (9*3+7) + 0.5
    assert Player.outcome?(state) == 0
  end

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

  test "#new_node", %{state: state}  do
    mc_rave_state = %MCRaveState{tree: {:root, []} }

    state = play_moves state, [       "B9", "C9", "D9", "E9", "F9", "G9", "H9", "J9",
                                "A8", "B8", "C8", "D8", "E8", "F8", "G8", "H8", "J8",
                                "A7", "B7", "C7", "D7", "E7", "F7", "G7", "H7", "J7",
                                "A6", "B6", "C6", "D6", "E6", "F6", "G6", "H6", "J6",
                                "A5", "B5", "C5", "D5", "E5", "F5", "G5", "H5", "J5",
                                "A4", "B4", "C4", "D4", "E4", "F4", "G4", "H4", "J4",
                                "A3", "B3", "C3", "D3", "E3", "F3", "G3", "H3", "J3",
                                "A2", "B2", "C2", "D2", "E2", "F2", "G2", "H2", "J2",
                                "A1", "B1", "C1", "D1", "E1", "F1", "G1", "H1", "J1" ], "White"

    state_hash = Player.state_hash state

    mc_rave_state = Player.new_node(state, :root, mc_rave_state)

    assert Dict.fetch!(mc_rave_state.n,       {state_hash, {9,1}}) == 5
    assert Dict.fetch!(mc_rave_state.q,       {state_hash, {9,1}}) == 0.5
    assert Dict.fetch!(mc_rave_state.n_tilde, {state_hash, {9,1}}) == 5
    assert Dict.fetch!(mc_rave_state.q_tilde, {state_hash, {9,1}}) == 0.5
  end

  test "#backup/backup_tilde" do
    mc_rave_state = %MCRaveState{}

    mc_rave_state = Player.backup mc_rave_state, [:state_0, :state_1], [:action_0, :action_1], [:action_2, :action_3, :action_4, :action_5], 1

    #t=0
    assert Dict.fetch!(mc_rave_state.n, {:state_0, :action_0}) == 1
    assert Dict.fetch!(mc_rave_state.q, {:state_0, :action_0}) == (1-0)/1
    #u = 0 -> nothing
    #u = 2 -> nothing
    #u = 4 -> subset => [:action_0, :action_2]
    assert Dict.fetch!(mc_rave_state.n_tilde, {:state_0, :action_4}) == 1
    assert Dict.fetch!(mc_rave_state.q_tilde, {:state_0, :action_4}) == (1-0)/1
    #t=1
    assert Dict.fetch!(mc_rave_state.n, {:state_1, :action_1}) == 1
    assert Dict.fetch!(mc_rave_state.q, {:state_1, :action_1}) == (1-0)/1
    #u = 1 -> nothing
    #u = 3 -> nothing
    #u = 5 subset => [:action_1, :action_3]
    assert Dict.fetch!(mc_rave_state.n_tilde, {:state_1, :action_5}) == 1
    assert Dict.fetch!(mc_rave_state.q_tilde, {:state_1, :action_5}) == (1-0)/1

    mc_rave_state = Player.backup mc_rave_state, [:state_0, :state_1], [:action_0, :action_1], [:action_6, :action_7, :action_8, :action_9], 0

    assert Dict.fetch!(mc_rave_state.n, {:state_0, :action_0}) == 2
    assert Dict.fetch!(mc_rave_state.q, {:state_0, :action_0}) == (1-0)/1 + (0-1)/2
    assert Dict.fetch!(mc_rave_state.n, {:state_1, :action_1}) == 2
    assert Dict.fetch!(mc_rave_state.q, {:state_1, :action_1}) == (1-0)/1 + (0-1)/2
  end

  test "will generate a move on an empty board", %{state: state} do
    assert Player.generate_move(Board.force_next_player(state, :black), 100) != :pass
  end

  test "will pick the only available move", %{state: state} do
    state = play_moves state, [       "B9", "C9", "D9", "E9", "F9", "G9", "H9", "J9",
                                "A8", "B8", "C8", "D8", "E8", "F8", "G8", "H8", "J8",
                                "A7", "B7", "C7", "D7", "E7", "F7", "G7", "H7", "J7",
                                "A6", "B6", "C6", "D6", "E6", "F6", "G6", "H6", "J6",
                                "A5", "B5", "C5", "D5", "E5", "F5", "G5", "H5", "J5",
                                "A4", "B4", "C4", "D4", "E4", "F4", "G4", "H4", "J4",
                                "A3", "B3", "C3", "D3", "E3", "F3", "G3", "H3", "J3",
                                "A2", "B2", "C2", "D2", "E2", "F2", "G2", "H2", "J2",
                                "A1", "B1", "C1", "D1", "E1", "F1", "G1", "H1", "J1" ], "Black"

    assert Player.generate_move(Board.force_next_player(state, :white), 100) == {9,1}
  end

  test "will pick the actual best move", %{state: state} do
    state = play_moves state, [                   "D9", "E9", "F9", "G9", "H9", "J9",
                                "A8", "B8", "C8", "D8", "E8", "F8", "G8", "H8", "J8",
                                "A7", "B7", "C7", "D7", "E7", "F7", "G7", "H7", "J7",
                                "A6", "B6", "C6", "D6", "E6", "F6", "G6", "H6", "J6",
                                "A5", "B5", "C5", "D5", "E5", "F5", "G5", "H5", "J5"], "Black"

    state = play_moves state, ["A4", "B4", "C4", "D4", "E4", "F4", "G4", "H4", "J4",
                               "A3", "B3", "C3", "D3", "E3", "F3", "G3", "H3", "J3",
                               "A2", "B2", "C2", "D2", "E2", "F2", "G2", "H2", "J2",
                               "A1",       "C1", "D1", "E1",       "G1", "H1", "J1"], "White"

    #Reset move counter to make it easier to debug outliers
    state = %{state | moves: 0}

    assert Player.outcome?(state) == 1
    assert Player.generate_move(Board.force_next_player(state, :white), 100) == {9,2}
  end
end
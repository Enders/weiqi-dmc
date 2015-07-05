defmodule WeiqiDMC.PlayerTest do
  use ExUnit.Case

  alias WeiqiDMC.Board
  alias WeiqiDMC.Player
  alias WeiqiDMC.Board.State

  doctest WeiqiDMC.Player

  setup do
    {:ok, board_agent} = Board.start_link
    Board.change_size board_agent, 9
    {:ok, board_agent: board_agent}
  end

  test "pass if no valid move left", %{board_agent: board_agent} do
    state = %{Board.state(board_agent) | board: List.duplicate(:black, 81) |> List.replace_at(0, :empty)}
    assert Player.generate_move(state, :black) == :pass
  end

  test "will pick the only available move", %{board_agent: board_agent} do
    state = %{Board.state(board_agent) | board: List.duplicate(:black, 81) |> List.replace_at(0, :empty)}
    assert Player.generate_move(state, :white) == 0
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
